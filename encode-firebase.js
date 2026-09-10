// Simple script to encode Firebase credentials to base64
const fs = require('fs');

const jsonFile = 'server/aviator-91a24-firebase-adminsdk-fbsvc-198cc2d269.json';
const jsonContent = fs.readFileSync(jsonFile, 'utf8');
const base64 = Buffer.from(jsonContent).toString('base64');

console.log('\n=== COPY THIS BASE64 STRING ===\n');
console.log(base64);
console.log('\n=== END ===\n');
console.log('Instructions:');
console.log('1. Copy the base64 string above');
console.log('2. Go to Render Dashboard → Environment');
console.log('3. Delete the old FIREBASE_SERVICE_ACCOUNT variable');
console.log('4. Add new variable:');
console.log('   Key: FIREBASE_SERVICE_ACCOUNT_BASE64');
console.log('   Value: [paste the base64 string]');
console.log('5. Save and wait for auto-redeploy');
