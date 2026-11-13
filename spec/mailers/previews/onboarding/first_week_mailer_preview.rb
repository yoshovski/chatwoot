# Previews of the first-week emails (T15) at /rails/mailers/onboarding/first_week_mailer. They use the first account
# with an administrator in the local database.
class Onboarding::FirstWeekMailerPreview < ActionMailer::Preview
  SCRIPT = <<~HTML.strip
    <script>
      (function(d,t) {
        var BASE_URL="https://app.chatoctave.com";
        var g=d.createElement(t),s=d.getElementsByTagName(t)[0];
        g.src=BASE_URL+"/packs/js/sdk.js";
        g.async = true;
        s.parentNode.insertBefore(g,s);
        g.onload=function(){
          window.chatwootSDK.run({
            websiteToken: 'abc123',
            baseUrl: BASE_URL
          })
        }
      })(document,"script");
    </script>
  HTML

  {
    day_0: ['onboarding_day_0', {}],
    day_1: ['onboarding_day_1', { 'script' => SCRIPT }],
    day_3: ['onboarding_day_3', { 'count' => 5, 'assistant_id' => 1,
                                  'questions' => ['Can your generator power a DJI T50?', 'Do you ship to Switzerland?',
                                                  'How long does the battery last on one charge?'] }],
    day_3_one: ['onboarding_day_3', { 'count' => 1, 'assistant_id' => 1, 'questions' => ['Do you ship to Switzerland?'] }],
    day_7: ['onboarding_day_7', { 'ends_at' => 7.days.from_now, 'used' => 23 }],
    day_7_capped: ['onboarding_day_7', { 'ends_at' => 7.days.from_now, 'used' => 23, 'limit' => 50 }],
    day_7_none: ['onboarding_day_7', { 'ends_at' => 7.days.from_now, 'used' => 0 }]
  }.each do |name, (kind, meta)|
    define_method(name) do
      account_user = AccountUser.administrator.first!
      Onboarding::FirstWeekMailer.with(account: account_user.account).notify(account_user, kind, meta)
    end
  end
end
