'use strict';
const {onDocumentWritten}=require('firebase-functions/v2/firestore');
const {onCall,HttpsError}=require('firebase-functions/v2/https');
const {onSchedule}=require('firebase-functions/v2/scheduler');
const admin=require('firebase-admin');
const crypto=require('node:crypto');
const engine=require('./monitoring_engine');
if(!admin.apps.length)admin.initializeApp();
const db=admin.firestore(),FV=admin.firestore.FieldValue;
const opts={region:'asia-southeast1',timeoutSeconds:120,memory:'256MiB'};
const dataDoc=uid=>db.doc(`users/${uid}/monitoring_state/current`);
const hash=value=>crypto.createHash('sha256').update(value).digest('hex').slice(0,40);
const stamp=d=>d&&typeof d.toDate==='function'?d.toDate():null;
async function refresh(uid) {
  const stateRef=dataDoc(uid),lock=db.doc(`monitoring_locks/${uid}`),leaseId=crypto.randomUUID();
  const acquired=await db.runTransaction(async tx=>{
    const old=(await tx.get(lock)).data();if(old?.until?.toMillis()>Date.now())return false;
    tx.set(lock,{leaseId,until:admin.firestore.Timestamp.fromMillis(Date.now()+115000)});return true;
  });
  if(!acquired)return {busy:true};
  try {
    const now=new Date();
    const [profileSnap,vitalsSnap,dosesSnap,settingsSnap]=await Promise.all([
      db.doc(`users/${uid}`).get(),db.collection(`users/${uid}/vitals`).where('recordedAt','>=',admin.firestore.Timestamp.fromMillis(now-35*86400000)).get(),
      db.collection(`users/${uid}/dose_events`).where('dueAt','>=',admin.firestore.Timestamp.fromMillis(now-9*86400000)).get(),db.doc(`users/${uid}/settings/monitoring`).get()]);
    if(!profileSnap.exists)return {missing:true};
    const profile=profileSnap.data(),settings=settingsSnap.data()||{};
    let zone=typeof settings.timeZone==='string'?settings.timeZone:'Asia/Kuala_Lumpur';
    try{engine.dayKey(now,zone);}catch(_){zone='Asia/Kuala_Lumpur';}
    const days=engine.buildDays({profile,vitals:vitalsSnap.docs.map(d=>({id:d.id,...d.data()})),doses:dosesSnap.docs.map(d=>d.data()),now,zone});
    for(let i=0;i<days.length;i++){
      const day=days[i],previous=days[i-1];
      day.dailyAnalysis=engine.analyze(days.slice(0,i+1));
      day.pressureDelta=day.pressure&&previous?.pressure?{systolic:day.pressure.systolic-previous.pressure.systolic,diastolic:day.pressure.diastolic-previous.pressure.diastolic}:null;
      day.glucoseDelta=day.glucose&&previous?.glucose&&day.glucose.context!=='unknown'&&day.glucose.context===previous.glucose.context?Math.round((day.glucose.value-previous.glucose.value)*10)/10:null;
    }
    const analysis=engine.analyze(days),summary=engine.report(days),today=days.at(-1);
    // Only the actual urgent measurement (not a newer weight/lab upload) can arm delivery.
    const urgent=[today.pressure,today.glucose].filter(m=>m?.level==='urgent').sort((a,b)=>new Date(b.at)-new Date(a.at))[0];
    const urgentAt=urgent?new Date(urgent.at):null;
    const urgentRecord=vitalsSnap.docs.find(d=>d.id===urgent?.sourceId);
    const received=stamp(urgentRecord?.data()?.recordedAt);
    const live=analysis.severity==='urgent'&&urgentAt&&now-urgentAt>=0&&now-urgentAt<15*60000&&received&&now-received>=0&&now-received<15*60000;
    const eventId=hash(`${uid}|${today.date}|${analysis.severity}|${analysis.flags.map(f=>f.code).sort().join(',')}|${live ? urgentAt.toISOString() : 'snapshot'}`);
    const payload={version:1,timeZone:zone,days,analysis,summary,eventId,liveUrgent:!!live,urgentReadingAt:urgentAt?urgentAt.toISOString():null,updatedAt:FV.serverTimestamp()};
    await stateRef.set(payload);
    if(today.observed||today.due>0){
      const ref=db.doc(`monitoring_events/${eventId}`);
      await db.runTransaction(async tx=>{
        if((await tx.get(ref)).exists)return;
        tx.create(ref,{uid,date:today.date,severity:analysis.severity,title:analysis.title,
          body:analysis.flags.map(f=>f.text).join(' ')||'Your recorded daily summary is ready. Review available components in the app.',
          action:analysis.action,liveUrgent:!!live,urgentReadingAt:urgentAt?urgentAt.toISOString():null,eventId,createdAt:FV.serverTimestamp(),status:'pending'});
      });
    }
    return {date:today.date,eventId};
  } finally {await db.runTransaction(async tx=>{const current=(await tx.get(lock)).data();if(current?.leaseId===leaseId)tx.delete(lock);});}
}
exports.refreshHealthMonitoring=onCall({...opts,enforceAppCheck:true},async request=>{
  if(!request.auth)throw new HttpsError('unauthenticated','Sign in to refresh monitoring.');
  const requested=typeof request.data?.ownerId==='string'?request.data.ownerId:request.auth.uid;
  if(!requested||requested.includes('/')||requested.length>128)throw new HttpsError('invalid-argument','Invalid patient identifier.');
  if(requested!==request.auth.uid){
    const link=(await db.doc(`users/${requested}/trackers/${request.auth.uid}`).get()).data();
    if(link?.shareMedication!==true)throw new HttpsError('permission-denied','Full monitoring requires approved medication sharing.');
  }
  return refresh(requested);
});
exports.monitorVitalChange=onDocumentWritten({...opts,document:'users/{uid}/vitals/{id}',retry:true},async event=>{
  const result=await refresh(event.params.uid);if(result.busy)throw new Error('Monitoring refresh busy; retry this change.');
});
exports.monitorDoseChange=onDocumentWritten({...opts,document:'users/{uid}/dose_events/{id}',retry:true},async event=>{
  const before=event.data?.before.data(),after=event.data?.after.data();
  if(before?.status===after?.status&&before?.dueAt?.isEqual(after?.dueAt))return;
  const at=stamp(after?.dueAt)||stamp(before?.dueAt);if(at&&at>new Date())return;
  const result=await refresh(event.params.uid);if(result.busy)throw new Error('Monitoring refresh busy; retry this change.');
});
exports.refreshMonitoringWindows=onSchedule({...opts,schedule:'every 15 minutes',timeZone:'Asia/Kuala_Lumpur'},async()=>{
  // Active dose schedules need refresh when the 20-minute grace period elapses.
  const start=admin.firestore.Timestamp.fromMillis(Date.now()-24*3600000),uids=new Set();let cursor;
  do {
    let q=db.collectionGroup('dose_events').where('dueAt','>=',start).orderBy('dueAt').limit(500);
    if(cursor)q=q.startAfter(cursor);
    const page=await q.get();for(const d of page.docs)uids.add(d.ref.parent.parent.id);
    if(page.size<500)break;cursor=page.docs.at(-1);
  }while(true);
  for(const uid of uids)await refresh(uid);
});
const {sendPush}=require('./fcm_transport');
const push=(uid,event,id)=>sendPush({db,FV,messaging:admin.messaging()},uid,event,id);
exports.deliverMonitoringAlert=onDocumentWritten({...opts,document:'monitoring_events/{id}',retry:true},async event=>{
  const d=event.data?.after.data();if(!d||d.status!=='pending')return;
  const urgentAge=Date.now()-Date.parse(d.urgentReadingAt||'');
  d.liveUrgent=d.liveUrgent===true&&Number.isFinite(urgentAge)&&urgentAge>=0&&urgentAge<15*60000;
  const ref=event.data.after.ref;
  const claimed=await db.runTransaction(async tx=>{
    const current=(await tx.get(ref)).data();if(current?.status==='finished')return false;
    if(current?.processingUntil?.toMillis()>Date.now())throw new Error('Delivery lease busy; retry.');
    tx.update(ref,{status:'processing',processingUntil:admin.firestore.Timestamp.fromMillis(Date.now()+115000)});return true;
  });
  if(!claimed)return;
  const settings=(await db.doc(`users/${d.uid}/settings/monitoring`).get()).data()||{},deliveries={};
  const deliveryRef=db.doc(`users/${d.uid}/monitoring_deliveries/${event.params.id}`);
  await deliveryRef.set({eventId:event.params.id,date:d.date,severity:d.severity,status:'processing',transport:'fcm',updatedAt:FV.serverTimestamp()});
  deliveries.owner=settings.pushEnabled===false?{status:'disabled'}:await push(d.uid,d,`${event.params.id}_owner`);
  if(settings.notifyCaregivers!==false&&['high','urgent'].includes(d.severity)){
    const trackers=await db.collection(`users/${d.uid}/trackers`).get();
    for(const tracker of trackers.docs){
      const currentLink=await tracker.ref.get();if(!currentLink.exists){deliveries[tracker.id]={status:'sharing_revoked'};continue;}
      const preferences=(await db.doc(`users/${tracker.id}/settings/monitoring`).get()).data()||{};
      if(preferences.receiveCaregiverPush===false){deliveries[tracker.id]={status:'recipient_disabled'};continue;}
      const caregiverEvent=currentLink.data().shareMedication===true?d:{...d,title:'Caregiver health alert',body:'A person who approved your health tracking has a reading requiring review. Contact them and view permitted data in Guardian.'};
      deliveries[tracker.id]=await push(tracker.id,caregiverEvent,`${event.params.id}_${tracker.id}`);
    }
  }
  const batch=db.batch();batch.update(ref,{status:'finished',push:deliveries,processedAt:FV.serverTimestamp()});
  batch.set(deliveryRef,{eventId:event.params.id,date:d.date,severity:d.severity,status:'finished',transport:'fcm',push:deliveries,updatedAt:FV.serverTimestamp()});await batch.commit();
});
