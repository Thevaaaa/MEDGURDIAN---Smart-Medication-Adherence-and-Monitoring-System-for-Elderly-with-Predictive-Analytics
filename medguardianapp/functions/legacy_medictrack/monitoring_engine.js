'use strict';
const number = v => { const n = v == null || v === '' ? NaN : Number(v); return Number.isFinite(n) ? n : null; };
const map = v => v && typeof v === 'object' && !Array.isArray(v) ? v : {};
const date = v => {const d = v && typeof v.toDate === 'function' ? v.toDate() : v instanceof Date ? v : typeof v === 'string' ? new Date(v) : null;return d && Number.isFinite(d.getTime())?d:null;};
function dayKey(v, zone = 'Asia/Kuala_Lumpur') {
  const d = date(v); if (!d || !Number.isFinite(d.getTime())) return null;
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: zone, year:'numeric',month:'2-digit',day:'2-digit' }).formatToParts(d);
  const get = key => parts.find(p => p.type === key).value;
  return `${get('year')}-${get('month')}-${get('day')}`;
}
function shiftDay(key, delta) { const d = new Date(`${key}T12:00:00Z`); d.setUTCDate(d.getUTCDate()+delta); return d.toISOString().slice(0,10); }
function bp(s, d) {
  if (!(s > 0 && d > 0)) return { level:'unknown', score:null, label:'Incomplete blood pressure' };
  if (s > 180 || d > 120) return {level:'urgent',score:20,label:'Very high blood pressure'};
  if (s >= 140 || d >= 90) return {level:'high',score:40,label:'High blood pressure · stage 2 reference'};
  if (s >= 130 || d >= 80) return {level:'high',score:60,label:'High blood pressure · stage 1 reference'};
  if (s < 90 || d < 60) return {level:'low',score:40,label:'Low blood pressure'};
  if (s >= 120) return {level:'watch',score:80,label:'Elevated blood pressure'};
  return {level:'reference',score:100,label:'Within pressure reference'};
}
function glucose(mg, context) {
  if (!(mg > 0)) return {level:'unknown',score:null,label:'Missing glucose'};
  if (mg < 54 - 1e-6) return {level:'urgent',score:20,label:'Very low glucose'};
  if (mg < 70 - 1e-6) return {level:'low',score:20,label:'Low glucose'};
  if (mg >= 300 - 1e-6) return {level:'urgent',score:20,label:'Very high glucose · confirm promptly'};
  if (context === 'beforeMeal' ? mg > 130 + 1e-6 : mg >= 180 - 1e-6) return {level:'high',score:40,label:'High glucose'};
  if (context === 'beforeMeal' && mg < 80 - 1e-6) return {level:'watch',score:80,label:'Below before-meal reference'};
  if (context === 'beforeMeal' || context === 'afterMeal') return {level:'reference',score:100,label:'Within glucose reference'};
  return {level:'unknown',score:null,label:'Meal timing needed'};
}
function a1c(value) {
  if (!(value > 0 && value <= 25)) return null;
  return {value,unit:'%',label:value >= 7 ? 'Above general adult diabetes A1c target' : 'Compare with your individual lab target',
    score:value >= 4 && value <= 6 ? 100 : value > 6 && value <= 7 ? 80 : value > 7 && value <= 8 ? 60 : value > 8 && value <= 10 ? 40 : 20};
}
const avg = values => { const v = values.filter(n => n != null); return v.length ? Math.round(v.reduce((a,b)=>a+b,0)/v.length*10)/10 : null; };
function currentStatic(profile, now) {
  const h = number(map(profile.healthInfo).height), w = number(map(profile.healthInfo).weight);
  const bmi = h > 0 && w > 0 ? w/((h/100)**2) : null;
  let age = number(profile.age);
  let dob = typeof profile.dateOfBirth === 'string' && profile.dateOfBirth.includes('/') ? null : date(profile.dateOfBirth);
  if (!dob && typeof profile.dateOfBirth === 'string') {
    const p = profile.dateOfBirth.split('/').map(Number);
    if (p.length === 3) { const d = new Date(Date.UTC(p[2],p[1]-1,p[0])); if (d.getUTCFullYear()===p[2] && d.getUTCMonth()===p[1]-1 && d.getUTCDate()===p[0]) dob=d; }
  }
  if (dob && Number.isFinite(dob.getTime()) && dob <= now) {
    age=now.getUTCFullYear()-dob.getUTCFullYear();
    if (now.getUTCMonth()<dob.getUTCMonth() || (now.getUTCMonth()===dob.getUTCMonth() && now.getUTCDate()<dob.getUTCDate())) age--;
  }
  if (!(age >= 1 && age <= 120)) age=null;
  return {bmi,age,bmiScore:bmi == null ? null : bmi >=18.5 && bmi<=24.9?100:bmi>=25&&bmi<=29.9?80:bmi>=30&&bmi<=34.9?60:bmi>=35&&bmi<=39.9?40:20,
    ageScore:age==null?null:age>=18&&age<=35?100:age<=50&&age>=36?80:age<=65&&age>=51?60:age<=75&&age>=66?40:20};
}
function buildDays({profile={},vitals=[],doses=[],now=new Date(),zone='Asia/Kuala_Lumpur',count=7}) {
  // Validate zone, and make day arithmetic calendar based instead of 24-hour durations.
  const today=dayKey(now,zone), stat=currentStatic(profile,new Date(`${today}T12:00:00Z`));
  const days=Array.from({length:count},(_,i)=>({date:shiftDay(today,i-count+1),pressure:null,glucose:null,a1c:null,
    taken:0,missed:0,pending:0,scheduled:0,due:0,adherence:null,bmi:null,age:null,bmiScore:null,ageScore:null,components:{},score:null,coverage:0,observed:false,latestReadingAt:null}));
  const byDay=new Map(days.map(d=>[d.date,d]));
  const readings=vitals.map(v=>({...v,_at:date(v.measuredAt)||date(v.recordedAt)||date(v.clientRecordedAt)}))
    .filter(v=>v._at&&Number.isFinite(v._at.getTime())&&v._at<=now).sort((a,b)=>a._at-b._at||String(a.id).localeCompare(String(b.id)));
  for (const record of readings) {
    const day=byDay.get(dayKey(record._at,zone)); if (!day) continue;
    const p=map(record.bloodPressure),g=map(record.bloodSugar),lab=map(record.hba1c);
    if (number(p.systolic)>0&&number(p.diastolic)>0) day.pressure={systolic:number(p.systolic),diastolic:number(p.diastolic),...bp(number(p.systolic),number(p.diastolic)),sourceId:record.id,at:record._at.toISOString()};
    const raw=number(g.value), unit=String(g.unit||'').toLowerCase();
    const mg=unit.includes('mmol')?(raw??number(g.valueMmol))*18:unit.includes('mg')?raw:null;
    if (mg>0) day.glucose={value:mg,unit:'mg/dL',context:g.readingContext||'unknown',...glucose(mg,g.readingContext),sourceId:record.id,at:record._at.toISOString()};
    if (a1c(number(lab.value))) day.a1c={...a1c(number(lab.value)),at:record._at.toISOString()};
    const snap=map(record.healthScoreSnapshot), signals=map(snap.signals),parts=map(snap.components);
    if (number(signals.bmiValue)>0) {day.bmi=number(signals.bmiValue);day.bmiScore=number(parts.bmi);}
    if (number(signals.ageYears)>0) {day.age=number(signals.ageYears);day.ageScore=number(parts.age);}
    day.observed=true;day.latestReadingAt=record._at.toISOString();
  }
  for (const event of doses) {
    const at=date(event.dueAt); if (!at || !Number.isFinite(at.getTime()) || event.status==='cancelled') continue;
    const day=byDay.get(dayKey(at,zone));if (!day) continue;day.scheduled++;
    if (at>now) {day.pending++;continue;}
    if (event.status==='taken') {day.taken++;day.due++;}
    else if (event.status==='missed'||now-at>20*60*1000) {day.missed++;day.due++;}
    else day.pending++;
  }
  for (const day of days) {
    if (day.date===today) {
      if (day.bmi==null) {day.bmi=stat.bmi;day.bmiScore=stat.bmiScore;}
      if (day.age==null) {day.age=stat.age;day.ageScore=stat.ageScore;}
    }
    day.adherence=day.due?Math.round(day.taken/day.due*1000)/10:null;
    day.components={bloodPressure:day.pressure?.score??null,bloodSugar:day.glucose?.score??null,adherence:day.adherence,bmi:day.bmiScore,age:day.ageScore};
    day.coverage=Object.values(day.components).filter(v=>v!=null).length;
    day.score=avg(Object.values(day.components));
    day.scoreBand=day.score==null?'No score':day.score>=90?'Excellent app score':day.score>=75?'Good app score':day.score>=60?'Moderate app score':day.score>=40?'Low app score':'Very low app score';
  }
  return days;
}
const elevated = metric => metric && ['high','urgent'].includes(metric.level);
function highRun(days,key) { let n=0;for(let i=days.length-1;i>=0;i--){if(!elevated(days[i][key]))break;n++;}return n; }
function rising(days,key,field) {const d=days.slice(-3);if(key==='glucose'&&d.some(v=>v.glucose?.context==='unknown'||v.glucose?.context!==d[0]?.glucose?.context))return false;return d.length===3&&d.every(v=>v[key]&&v[key][field]!=null)&&d[0][key][field]<d[1][key][field]&&d[1][key][field]<d[2][key][field];}
function changedDirection(days,key,field) {const d=days.slice(-3);if(key==='glucose'&&d.some(v=>v.glucose?.context==='unknown'||v.glucose?.context!==d[0]?.glucose?.context))return false;if(d.length<3||d.some(v=>v[key]?.[field]==null))return false;const a=d[1][key][field]-d[0][key][field],b=d[2][key][field]-d[1][key][field];return a*b<0;}
function analyze(days) {
  const today=days.at(-1),previous=days.at(-2); if(!today)return null;
  const flags=[];let severity='info';
  const add=(code,level,text)=>{flags.push({code,level,text});if(['info','watch','high','urgent'].indexOf(level)>['info','watch','high','urgent'].indexOf(severity))severity=level;};
  if(today.pressure?.level==='urgent')add('urgent_bp','urgent','Very high pressure recorded. Repeat promptly; emergency symptoms need immediate help.');
  if(today.glucose?.level==='urgent')add('urgent_glucose','urgent','Very high or very low glucose recorded. Confirm promptly and follow urgent-care guidance.');
  for(const key of ['glucose','pressure']) {
    const name=key==='glucose'?'Glucose':'Blood pressure',run=highRun(days,key);
    if(run>=4)add(`${key}_persistent4`,'high',`${name} is above its reference on ${run} consecutive recorded calendar days. Arrange prompt clinician review.`);
    else if(run>=3)add(`${key}_persistent3`,'high',`${name} is above its reference on 3 consecutive recorded calendar days. Share the log with your care team.`);
    else if(elevated(today[key]))add(`${key}_high`,'watch',`${name} is above its reference today.`);
    if(today[key]?.level==='low')add(`${key}_low`,'high',`${name} is below its reference today. Follow your care plan and seek help if unwell.`);
  }
  if(rising(days,'glucose','value')||rising(days,'pressure','systolic')||rising(days,'pressure','diastolic'))add('rising3','watch','Readings have increased across three consecutive calendar days; this is a numerical trend, not proof of deterioration.');
  if(changedDirection(days,'glucose','value')||changedDirection(days,'pressure','systolic')||changedDirection(days,'pressure','diastolic'))add('fluctuation','watch','Readings changed direction across three days. Meal timing, measurement conditions and other factors may affect this pattern.');
  if(today.a1c?.value>=7)add('lab_review','watch','The recorded HbA1c lab value is above the general adult diabetes target. Review it with your clinician; it does not represent a daily glucose spike.');
  if(today.missed>0)add('missed','watch',`${today.missed} due dose(s) are unconfirmed after the grace period. Do not take extra or catch-up doses based on this app.`);
  if(today.missed>0&&(elevated(today.glucose)||elevated(today.pressure)))add('cooccurrence','watch','Above-reference readings and unconfirmed doses occurred on the same day. These records do not establish cause.');
  const keys=Object.keys(today.components).filter(k=>today.components[k]!=null);
  const comparable=previous&&keys.length>0&&Object.keys(previous.components).filter(k=>previous.components[k]!=null).join('|')===keys.join('|');
  const delta=comparable?Math.round((today.score-previous.score)*10)/10:null;
  const title=severity==='urgent'?'Urgent reading review':severity==='high'?'Persistent or low reading alert':severity==='watch'?'Your readings need attention':today.observed?'Your daily summary':'More measurements needed';
  return {severity,title,flags,delta,glucoseHighDays:highRun(days,'glucose'),pressureHighDays:highRun(days,'pressure'),
    action:severity==='urgent'?'Check the urgent-reading guidance now. Use local emergency services for serious symptoms; do not wait for a caregiver reply.':severity==='high'?'Arrange clinician review and share your records. Continue medicines only as prescribed.':'Keep recording comparable measurements and follow your prescribed schedule.',
    note:'Monitoring estimates support awareness, not diagnosis. Missing days break a consecutive-day pattern. HbA1c lab results are separate from daily glucose. No causal conclusion is made.'};
}
function report(days) {
  const total=days.reduce((a,d)=>a+d.due,0),taken=days.reduce((a,d)=>a+d.taken,0);
  return {averageScore:avg(days.filter(d=>d.observed||d.due>0).map(d=>d.score)),scoreDays:days.filter(d=>(d.observed||d.due>0)&&d.score!=null).length,
    taken,due:total,adherence:total?Math.round(taken/total*1000)/10:null,
    glucoseAverage:avg(days.map(d=>d.glucose?.value)),systolicAverage:avg(days.map(d=>d.pressure?.systolic)),diastolicAverage:avg(days.map(d=>d.pressure?.diastolic)),
    measuredDays:days.filter(d=>d.observed).length,urgentDays:days.filter(d=>d.pressure?.level==='urgent'||d.glucose?.level==='urgent').map(d=>d.date),
    cooccurrenceDays:days.filter(d=>d.missed>0&&(elevated(d.glucose)||elevated(d.pressure))).map(d=>d.date),
    aboveReferenceGlucoseDays:days.filter(d=>elevated(d.glucose)).length,aboveReferencePressureDays:days.filter(d=>elevated(d.pressure)).length,latestA1c:days.map(d=>d.a1c).filter(Boolean).at(-1)||null};
}
module.exports={number,dayKey,shiftDay,bp,glucose,a1c,buildDays,analyze,report};
