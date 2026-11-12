# Afterbell Academy অ্যাপ: GitHub দিয়ে সেটআপ (কম্পিউটারে Flutter লাগবে না)

    Flutter অ্যাপ (Android)  →  Next.js backend (Vercel)  →  WordPress সাইট (ডেটা)

## ধাপ ১: WordPress থিম
`afterbell-academy.zip` (v6.1.0) আপলোড করে Replace current দিন।
পরীক্ষা: `https://afterbellacademy.com/wp-json/afterbell/v1/app/home` খুললে ডেটা দেখাবে।
৪০৪ এলে Settings → Permalinks → Save Changes।

## ধাপ ২: GitHub-এ সব ফাইল তোলা
1. github.com-এ লগইন → New repository → নাম দিন (যেমন `afterbell-app`) → Create।
   Public করলে APK-এর ডাউনলোড লিংক যে কেউ খুলতে পারবে। Private করলে শুধু আপনি নামাতে পারবেন।
2. এই জিপটি কম্পিউটারে খুলুন (Extract)।
3. repository-তে "uploading an existing file" → জিপের ভেতরের **সব কিছু** টেনে ছেড়ে দিন:
   `afterbell-backend`, `afterbell_app`, `.github` ফোল্ডার এবং README (একটি একটি করে ফোল্ডার তুললে ভালো) → Commit changes।
4. `.github` ফোল্ডারটি লুকানো থাকতে পারে এবং আপলোডে বাদ পড়তে পারে। আপলোডের পর repository-তে
   `.github/workflows/build-apk.yml` আছে কিনা দেখুন। না থাকলে: Add file → Create new file →
   নামের ঘরে লিখুন `.github/workflows/build-apk.yml` → জিপের ওই ফাইলটি Notepad-এ খুলে পুরো লেখা পেস্ট করুন → Commit।

## ধাপ ৩: Backend Vercel-এ চালু করা
1. vercel.com → Continue with GitHub → Add New → Project → আপনার repository → Import।
2. **Root Directory**-তে Edit চেপে `afterbell-backend` বেছে নিন (এটা জরুরি)।
3. Environment Variables: নাম `WP_URL`, মান `https://afterbellacademy.com` → Deploy।
4. Vercel যে ঠিকানা দেবে তার শেষে `/api/health` বসিয়ে খুলুন। `"ok":true` দেখালে চালু। ঠিকানাটা কপি করে রাখুন।

## ধাপ ৪: GitHub দিয়ে APK বানানো
1. repository → উপরের **Actions** ট্যাব (প্রথমবার "I understand my workflows, go ahead and enable them" চাপতে হতে পারে)।
2. বাঁ পাশে **Build Android APK** → ডান পাশে **Run workflow**।
3. ঘরে Vercel-এর ঠিকানা দিন, যেমন `https://afterbell-app.vercel.app` (শেষে `/api` বা `/` নয়) → Run workflow।
4. ১০ থেকে ১৫ মিনিট অপেক্ষা করুন। সবুজ টিক এলে সফল।
   লাল ক্রস এলে সেই রানে ঢুকে লাল ধাপটি খুলুন, ত্রুটির লেখা কপি করে Claude-কে পাঠান।

## ধাপ ৫: APK নামানো ও শেয়ার করা
- repository-র প্রথম পাতায় ডান পাশে **Releases** → সবচেয়ে নতুনটি → `afterbell-academy.apk`।
- repository Public হলে এই পাতার লিংকই অন্যদের পাঠাতে পারেন।
- Private হলে APK নিজে নামিয়ে Google Drive-এ তুলে "Anyone with the link" করে লিংক পাঠান।
- ইনস্টলের সময় ফোনে "Install unknown apps" অনুমতি দিতে হবে। শুধু Android-এ চলবে।

## পরে কোড বদলালে
ফাইল GitHub-এ আপডেট করুন, তারপর আবার ধাপ ৪। Vercel নিজে থেকেই নতুন backend চালু করে।

## ঐচ্ছিক: অ্যাপ কী (বাড়তি সুরক্ষা)
WordPress অ্যাডমিন → Afterbell → Live classroom → "Mobile app key"-তে একটি লম্বা এলোমেলো মান দিন,
আর Vercel-এ একই মান `WP_APP_KEY` নামে দিয়ে Redeploy করুন।
