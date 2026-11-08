'use strict';
async function sendPush({db,FV,messaging},uid,event,notificationId) {
  const ref=db.doc(`notifications/${notificationId}`);
  await db.runTransaction(async tx=>{if(!(await tx.get(ref)).exists)tx.create(ref,{userId:uid,type:'health_monitoring',title:event.title,
    body:event.body,read:false,createdAt:FV.serverTimestamp(),data:{eventId:event.eventId,ownerId:event.uid,severity:event.severity}});});
  const attempt=db.doc(`monitoring_events/${event.eventId}/recipients/${uid}`);
  const claim=await db.runTransaction(async tx=>{const current=(await tx.get(attempt)).data();if(current)return current;tx.create(attempt,{status:'submitting',createdAt:FV.serverTimestamp()});return null;});
  if(claim)return claim.status==='submitting'?{status:'delivery_unknown'}:claim;
  let delivery;
  try {
    const [primary,profile]=await Promise.all([db.doc(`user_tokens/${uid}`).get(),db.doc(`users/${uid}`).get()]);
    const list=v=>Array.isArray(v)?v.filter(t=>typeof t==='string'&&t.trim()):[];
    const tokens=[...new Set([...list(primary.data()?.tokens),...list(profile.data()?.fcmTokens)])];
    if(!tokens.length)delivery={status:'no_registered_device',success:0,failed:0};
    else {
      let success=0,failed=0;const invalid=[];
      for(let i=0;i<tokens.length;i+=500){
        const chunk=tokens.slice(i,i+500);
        const result=await messaging.sendEachForMulticast({tokens:chunk,
          notification:{title:event.title,body:event.body.slice(0,900)},data:{type:'health_monitoring',severity:event.severity,ownerId:event.uid,eventId:event.eventId},
          android:{priority:'high',ttl:15*60*1000,notification:{channelId:event.liveUrgent?'health_urgent':'medicine_alerts',sound:'default',tag:event.eventId}},
          apns:{headers:{'apns-expiration':String(Math.floor(Date.now()/1000)+900)},payload:{aps:{sound:'default'}}}});
        success+=result.successCount;failed+=result.failureCount;
        result.responses.forEach((r,index)=>{if(['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(r.error?.code))invalid.push(chunk[index]);});
      }
      delivery={status:success?(failed?'partially_accepted_by_fcm':'accepted_by_fcm'):'fcm_rejected',success,failed};
      if(invalid.length){
        await Promise.allSettled([primary.exists?primary.ref.update({tokens:FV.arrayRemove(...invalid)}):Promise.resolve(),
          profile.exists?profile.ref.update({fcmTokens:FV.arrayRemove(...invalid)}):Promise.resolve()]);
      }
    }
  } catch(error){delivery={status:'failed_or_unknown',errorCode:String(error.code||'request_error')};}
  await attempt.set({...delivery,updatedAt:FV.serverTimestamp()},{merge:true});return delivery;
}
module.exports={sendPush};
