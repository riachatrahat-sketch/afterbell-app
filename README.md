# Afterbell Academy অ্যাপ: GitHub দিয়ে সেটআপ (কম্পিউটারে Flutter লাগবে না)

    Flutter অ্যাপ (Android)  →  Next.js backend (Vercel)  →  WordPress সাইট (ডেটা)

## ধাপ ১: WordPress থিম
`afterbell-THEME-v6.5.0.zip` আপলোড করে Replace current দিন (Appearance → Themes → Add New → Upload)।
পরীক্ষা: `https://afterbellacademy.com/wp-json/afterbell/v1/app/home` খুললে ডেটা দেখাবে।
৪০৪ এলে Settings → Permalinks → Save Changes।

## ধাপ ২: GitHub
ফাইলগুলো এই repository-তে আগে থেকেই আছে: `afterbell-backend`, `afterbell_app`, `.github`।

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


## নতুন (v6.5.0): অনুমোদন, নোটিশ ও সাপোর্ট চ্যাট
- **Approval:** অ্যাপে নতুন Student/Parent বা Teacher অ্যাকাউন্ট "Pending" থাকে। WordPress অ্যাডমিন → **App members → Approvals**-এ Approve বা Reject করুন। ইমেইল চলে যায়। Teacher approve করলে তার ইমেইল দিয়ে একটি teacher প্রোফাইল তৈরি হয়, এতে সে ক্লাস চালাতে (host) পারে।
- **আগের অ্যাকাউন্ট:** আগে থেকে থাকা বা ওয়েবসাইটে খোলা অ্যাকাউন্ট approved ধরা হয়, তাই কেউ লক হবে না।
- **Notices:** **App members → App notices → Add notice** থেকে লিখুন (সবাই / শুধু student / শুধু teacher)। Approved teacher অ্যাপ থেকেও নিজের student-দের notice দিতে পারে।
- **Support chat:** অ্যাপে Account → Help & support। উত্তর দিন **App members → Support chats**-এ। নতুন মেসেজ এলে অ্যাডমিন ইমেইলে খবর যায়।
- **Backend:** নতুন রুট `/api/notices` ও `/api/support`। Vercel-এ নতুন করে Deploy হবে (GitHub-এ ফাইল তুললেই হয়)। নতুন Environment Variable লাগবে না।
- অ্যাডমিন ইমেইল (Settings → General) ঠিক আছে কি না দেখে নিন, কারণ approval ও chat-এর খবর সেখানে যায়।
