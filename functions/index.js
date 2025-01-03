const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// 매일 00시 - 일간 랭킹 초기화 및 일간 명예의 전당 등록
exports.resetDailyVotes = functions.pubsub
 .schedule('0 0 * * *')  // 매일 00:00
 .timeZone('Asia/Seoul')
 .onRun(async (context) => {
   const db = admin.firestore();

   try {
     // 1. 일간 1등 찾기 (초기화 전)
     const topCategoriesSnapshot = await db
       .collection('categories')
       .orderBy('dailyVotes', 'desc')
       .get();

     if (!topCategoriesSnapshot.empty) {
       const highestVotes = topCategoriesSnapshot.docs[0].data().dailyVotes;

       // 1표 이상인 경우에만 처리
       if (highestVotes >= 1) {
         // 동점자 모두 찾기
         const winners = topCategoriesSnapshot.docs.filter(
           doc => doc.data().dailyVotes === highestVotes
         );

         // 각 우승자를 일간 명예의 전당에 추가
         for (const winner of winners) {
           const winnerData = winner.data();
           await db.collection('dailyHallOfFame').add({
             categoryId: winner.id,
             categoryName: winnerData.name,
             categoryImage: winnerData.imageUrl,
             votes: winnerData.dailyVotes,
             date: admin.firestore.Timestamp.now(),
             createdAt: admin.firestore.FieldValue.serverTimestamp()
           });

           console.log(`Added ${winnerData.name} to Daily Hall of Fame with ${winnerData.dailyVotes} votes`);
         }
       }
     }

     // 2. 일간 투표 초기화
     const snapshot = await db.collection('categories').get();
     const batch = db.batch();

     snapshot.docs.forEach((doc) => {
       batch.update(doc.ref, {
         'dailyVotes': 0
       });
     });

     await batch.commit();
     console.log('Daily votes reset successful');

     // 3. 사용자 투표권 초기화
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
     // 1. 월간 1등 찾기 (초기화 전)
     const topCategoriesSnapshot = await db
       .collection('categories')
       .orderBy('monthlyVotes', 'desc')
       .get();

     if (!topCategoriesSnapshot.empty) {
       const highestVotes = topCategoriesSnapshot.docs[0].data().monthlyVotes;

       // 1표 이상인 경우에만 처리
       if (highestVotes >= 1) {
         // 동점자 모두 찾기
         const winners = topCategoriesSnapshot.docs.filter(
           doc => doc.data().monthlyVotes === highestVotes
         );

         const lastMonth = new Date();
         lastMonth.setMonth(lastMonth.getMonth() - 1);

         // 각 우승자를 명예의 전당에 추가
         for (const winner of winners) {
           const winnerData = winner.data();
           await db.collection('hallOfFame').add({
             categoryId: winner.id,
             categoryName: winnerData.name,
             categoryImage: winnerData.imageUrl,
             votes: winnerData.monthlyVotes,
             month: new Date(lastMonth.getFullYear(), lastMonth.getMonth(), 1),
             createdAt: admin.firestore.FieldValue.serverTimestamp()
           });

           console.log(`Added ${winnerData.name} to Hall of Fame with ${winnerData.monthlyVotes} votes`);
         }
       }
     }

     // 2. 월간 투표 및 전체 투표 수 초기화
     const snapshot = await db.collection('categories').get();
     const batch = db.batch();

     snapshot.docs.forEach((doc) => {
       const currentData = doc.data();
       batch.update(doc.ref, {
         'monthlyVotes': 0,
         'totalVotes': currentData.monthlyVotes || 0
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