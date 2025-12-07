// 테스트용 일반/관리자 계정을 생성하는 스크립트
// node ./functions/create_test_users.js 로 한 번 실행하면 됩니다.

const admin = require('firebase-admin');

// 로컬에 있는 Firebase 서비스 계정 키를 이용해 Admin SDK 초기화
// 이 JSON 파일은 .gitignore에 의해 GitHub에는 올라가지 않습니다.
const serviceAccount = require('../grantscout-af8da-firebase-adminsdk-fbsvc-b0ec7c1b62.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'grantscout-af8da',
  });
}

const auth = admin.auth();
const db = admin.firestore();

async function ensureUser(email, password, role) {
  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
    console.log(`[INFO] 이미 존재하는 계정: ${email} (uid=${userRecord.uid})`);
  } catch (err) {
    if (err.code === 'auth/user-not-found') {
      userRecord = await auth.createUser({
        email,
        password,
        emailVerified: true,
        disabled: false,
      });
      console.log(`[INFO] 새 계정 생성: ${email} (uid=${userRecord.uid})`);
    } else {
      console.error('[ERROR] getUserByEmail 실패:', err);
      throw err;
    }
  }

  // Firestore users 문서에 기본 프로필/role 저장
  await db.collection('users').doc(userRecord.uid).set(
    {
      email,
      role,
      scrapeCount: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  console.log(`[INFO] Firestore users/${userRecord.uid} 업데이트 완료 (role=${role})`);
  return userRecord.uid;
}

async function main() {
  try {
    console.log('=== QA 테스트 계정 생성 시작 ===');

    // 일반 유저 계정
    await ensureUser('qa.user@padiemaiscout.com', 'QaUser!2025', 'free');

    // 관리자 계정 (코드 상에서 admin 네비게이션 화이트리스트에 포함된 이메일)
    await ensureUser('limone@example.com', 'QaAdmin!2025', 'admin');

    console.log('=== QA 테스트 계정 생성 완료 ===');
    process.exit(0);
  } catch (e) {
    console.error('[FATAL] 테스트 계정 생성 중 오류:', e);
    process.exit(1);
  }
}

main();
