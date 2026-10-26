# App Review reply + Notes (Guideline 2.1 Information Needed)

Paste everything between the lines into BOTH:
1. App Store Connect → App Review → the rejected submission → **Reply to App Review**
2. App Store Connect → iOS App 1.0 → **App Review Information → Notes**

Fill in the three `<<…>>` items first. Attach the screen recording to the reply.

---

Hello App Review team,

Thank you for reviewing EliteMeet. Here is the information you asked for.

**1. Screen recording**
Attached is a screen recording made on a physical iPhone running the latest iOS. It starts with launching the app and shows:
- Account registration (email and Sign in with Apple), login, and onboarding.
- Discovery, matching and chat (user-generated content).
- Reporting and blocking a user: open any profile → "Report <name>" / "Block <name>". Comments in Lounges also have a "Report" option. Reports go to our moderation team, and blocked users are hidden immediately.
- Paid content: the subscription screen showing each subscription's title, length (1 month) and price, the auto-renewal terms, and links to the Terms of Use and Privacy Policy. Then a sandbox purchase, and Settings → Restore purchases.
- Account deletion: Profile → Settings → Delete account → type DELETE → Permanently delete account. The account and its data are deleted immediately, and the user is signed out.

**2. Purpose and target audience**
EliteMeet is a dating and social discovery app for verified adults aged 18 and over. Many dating apps have fake profiles and awkward first conversations. EliteMeet addresses this with ID-verified profiles, icebreaker mini-games, interest-based community "Lounges", and in-app voice/video calls, so people can get to know each other safely before meeting.

**3. Setup and demo account**
Demo account (already onboarded and verified, so you won't need to complete ID verification):
- Email: <<demo email>>
- Password: <<demo password>>

Steps: launch the app → Sign in → enter the credentials above. The main features are on the bottom tabs: Discover (swipe), Matches/Chat, Explore, Lounges and Profile. Settings is under Profile (gear icon). To test purchases, use a Sandbox Apple Account.

**4. External services**
- Supabase: user accounts, authentication and database
- Sign in with Apple and Google Sign-In: optional login methods
- Apple In-App Purchase (StoreKit), verified with the App Store Server API: all in-app digital purchases
- Firebase Cloud Messaging: push notifications
- Agora: in-app voice and video calls
- Didit: identity / age verification
- Cloudflare (Workers hosting, R2 photo storage)
- BigDataCloud: converts location to city name for "people nearby"
- SMTP email provider: account emails (confirmation, password reset)
The app doesn't use AI services. Inside the iOS app, all digital goods are sold only through Apple In-App Purchase.

**5. Regional differences**
The app works the same in all regions where it's available. Features and content don't vary by region. Prices are set per storefront by App Store pricing.

**6. Regulated industry / third-party material**
EliteMeet isn't in a highly regulated industry and doesn't include protected third-party content. All content is created by users and moderated under our Terms of Use and Community Guidelines (https://elitemeet.net/legal/terms, https://elitemeet.net/legal/community).

**7. In-App Purchases and how to find them**
Subscriptions (auto-renewing, group "EliteMeet Membership"):
- EliteMeet Plus, 1 month: unlimited likes, more Super Likes and Rewinds, and other premium features
- EliteMeet Gold, 1 month: everything in Plus, plus higher limits

Consumables:
- Super Likes (1 or 5) and Rewinds (1 or 5)
- Boost: 24 hours, 7 days or 30 days (profile shown to more people)
- Message Bundle: extra messages
- Unlimited Chat: 24 hours, 7 days or 30 days
- Verification fee: unlocks ID verification

How to reach them:
- Subscriptions: Profile → Upgrade / Premium. The subscription screen also opens when a free limit is reached.
- Super Likes, Rewinds and Boost: the buttons on the Discover (swipe) screen, when the user has none left.
- Message Bundle and Unlimited Chat: in a chat, when the free message limit is reached.
- Verification fee: Profile → Get verified.
- Restore purchases: Profile → Settings → Restore purchases.
Terms of Use: https://elitemeet.net/legal/terms. Privacy Policy: https://elitemeet.net/legal/privacy

Contact: support@elitemeet.net

Thank you,
Samuel Githaka, ELITEMEET LLC

---

## Checklist before replying

- [ ] Website change `ade5077` (Settings → Delete account) pushed and deployed to elitemeet.net
- [ ] Demo account created, onboarded and verified, with a few matches/chats so the reviewer sees content
- [ ] Recording made on a real iPhone, latest iOS, starting from the home screen tap on the app icon
- [ ] Recording shows the subscription screen with price, length, auto-renew text, Terms and Privacy links
- [ ] Recording shows Report + Block, and the full Delete account flow (use a throwaway account, not the demo one)
- [ ] Demo credentials also entered in App Review Information → Sign-in required
- [ ] App Store screenshots show the app in use, not the login/splash screen (2.3.3)
- [ ] Every navigation path in section 7 checked against the real app (edit the text if a button is named differently)
