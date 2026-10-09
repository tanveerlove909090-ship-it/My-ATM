# Nova Wallet — Online starter bundle

This bundle contains a front end and a Supabase database schema to help you deploy the basic customer/admin workflow. It is **not a production-ready financial service** and does not connect to a bank or payment gateway.

## Files
- `public/index.html` — website front end
- `supabase/schema.sql` — tables, row-level security policies, owner-only approval function
- `README.md` — setup guide

## 1. Create the backend/database
1. Create a Supabase project at https://supabase.com/ (a free tier may be available; check current terms).
2. Open **SQL Editor → New query**.
3. Copy all of `supabase/schema.sql`, paste it, and run it.
4. Open **Project Settings → API** (or API Keys). Copy the Project URL and the `anon` / publishable public key. **Never use the `service_role` key in browser code.**

## 2. Configure the website
1. Open `public/index.html` in a text editor.
2. Near the bottom, find:
   `const SUPABASE_URL = "PASTE_SUPABASE_PROJECT_URL_HERE";`
   `const SUPABASE_ANON_KEY = "PASTE_SUPABASE_ANON_KEY_HERE";`
3. Replace those placeholders with your project URL and public anon/publishable key. Keep the quotes.
4. Save the file.

## 3. Create your owner account
1. Temporarily host the page or open it through a local web server. Sign up with your own email.
2. Confirm your email if Supabase asks.
3. In Supabase **Authentication → Users**, find your account and copy its user UUID.
4. In SQL Editor, run the following with your exact UUID:
   `update public.profiles set role='owner' where id='YOUR_AUTH_USER_UUID';`
5. Sign out and sign back in. The Owner Admin tab should now verify your role.
6. Do not set other accounts to owner. Do not share your login.

## 4. Publish the website
1. Go to https://pages.cloudflare.com/ and create a Pages project using the upload/direct-upload option if available in your account.
2. Upload the contents of the `public` folder (the `index.html` file must be at the site root).
3. Open the generated public URL and test with a separate customer account.
4. Check Supabase Authentication URL settings and add your public site URL to the allowed redirect/site URL settings as required by your project.

## 5. What works / what does not
- Customer email/password signup and login (once Supabase is configured).
- Each signed-in customer sees only their own wallet, deposit requests, and transaction history.
- Customer can submit a deposit request.
- Owner role is checked in the database; owner can approve/reject pending requests.
- Approval credits the demo/database wallet and writes a transaction record.
- **No actual money is received or transferred.** The reference entered by a customer is not proof of payment. Verify incoming transfers independently before approving.
- No password reset UI, email notifications, identity verification, provider payment integration, compliance checks, or monitoring is included.
- Review SQL policies and test carefully before public use. The schema does not include a customer ability to transfer money to another customer.

## Security and financial-use warning
This starter is for learning/prototyping. Do not hold customer funds or advertise it as a real wallet. Before handling real funds, work with a qualified adult and a properly licensed/authorized payment provider, and get a professional security and legal review. Never collect bank credentials, card PINs, or OTPs.
