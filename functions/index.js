const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// 매일 00시 - 일간 랭킹 초기화
exports.resetDailyVotes = functions.pubsub
 .schedule('0 0 * * *')  // 매일 00:00
 .timeZone('Asia/Seoul')
 .onRun(async (context) => {
   const db = admin.firestore();

   try {
     const snapshot = await db.collection('categories').get();
     const batch = db.batch();

     snapshot.docs.forEach((doc) => {
       batch.update(doc.ref, {
         'dailyVotes': 0
       });
     });

     await batch.commit();
     console.log('Daily votes reset successful');

     // 사용자 투표권 초기화
     const usersSnapshot = await db.collection('users').get();
     const usersBatch = db.batch();

     usersSnapshot.docs.forEach((doc) => {
       usersBatch.update(doc.ref, {
         'remainingVotes': 1
       });
     });

     await usersBatch.commit();
     console.log('Vote permissions reset successful');

     return null;
   } catch (error) {
     console.error('Error in daily reset:', error);
     throw error;
   }
 });

// 매주 월요일 00시 - 주간 랭킹 초기화
exports.resetWeeklyVotes = functions.pubsub
 .schedule('0 0 * * 1')  // 매주 월요일 00:00
 .timeZone('Asia/Seoul')
 .onRun(async (context) => {
   const db = admin.firestore();

   try {
     const snapshot = await db.collection('categories').get();
     const batch = db.batch();

     snapshot.docs.forEach((doc) => {
       batch.update(doc.ref, {
         'weeklyVotes': 0
       });
     });

     await batch.commit();
     console.log('Weekly votes reset successful');
     return null;
   } catch (error) {
     console.error('Error resetting weekly votes:', error);
     throw error;
   }
 });

// 매월 1일 00시 - 월간 랭킹 초기화 및 명예의 전당 등록
exports.resetMonthlyVotes = functions.pubsub
 .schedule('0 0 1 * *')  // 매월 1일 00:00
 .timeZone('Asia/Seoul')
 .onRun(async (context) => {
   const db = admin.firestore();

   try {
     // 1. 지난 달의 1등 찾기 (초기화 전에 실행)
     const topCategorySnapshot = await db
       .collection('categories')
       .orderBy('monthlyVotes', 'desc')
       .limit(1)
       .get();

     if (!topCategorySnapshot.empty) {
       const winner = topCategorySnapshot.docs[0];
       const winnerData = winner.data();

       // 최소 투표 수 체크 (예: 10표 이상으로 낮춤)
       if (winnerData.monthlyVotes >= 10) {
         const lastMonth = new Date();
         lastMonth.setMonth(lastMonth.getMonth() - 1);

         // 2. 명예의 전당에 추가
         await db.collection('hallOfFame').add({
           categoryId: winner.id,
           categoryName: winnerData.name,
           categoryImage: winnerData.imageUrl,
           votes: winnerData.monthlyVotes,
           month: new Date(lastMonth.getFullYear(), lastMonth.getMonth(), 1),
           createdAt: admin.firestore.FieldValue.serverTimestamp()
         });

         console.log(`Added ${winnerData.name} to Hall of Fame with ${winnerData.monthlyVotes} votes`);
       } else {
         console.log(`Winner ${winnerData.name} did not meet minimum vote requirement`);
       }
     }

     // 3. 월간 투표 및 전체 투표 수 초기화
     const snapshot = await db.collection('categories').get();
     const batch = db.batch();

     snapshot.docs.forEach((doc) => {
       const currentData = doc.data();
       batch.update(doc.ref, {
         'monthlyVotes': 0,
         'totalVotes': currentData.monthlyVotes || 0  // 이번달 투표수를 전체 투표수로 설정
       });
     });

     await batch.commit();
     console.log('Monthly votes reset and total votes updated successful');

     return null;
   } catch (error) {
     console.error('Error in monthly reset and Hall of Fame update:', error);
     throw error;
   }
 });

// 재시도 로직을 위한 함수 실행 기록
async function logFunctionExecution(functionName, status, error = null) {
 const db = admin.firestore();

 try {
   await db.collection('functionExecutions').add({
     functionName,
     status,
     error: error ? {
       message: error.message,
       stack: error.stack
     } : null,
     executedAt: admin.firestore.FieldValue.serverTimestamp()
   });
 } catch (e) {
   console.error('Error logging function execution:', e);
 }
}