// Finicky v4 configuration with TypeScript
// See: https://github.com/johnste/finicky/wiki/Configuration-(v4)

import type { FinickyConfig } from "/Applications/Finicky.app/Contents/Resources/finicky.d.ts";

// Chrome profile *display* names, exactly as they appear in Chrome's profile
// switcher. Finicky matches these against `profile.info_cache[*].name` in
// ~/Library/Application Support/Google/Chrome/Local State, and a name that
// doesn't match is silently ignored: it drops --profile-directory entirely
// and Chrome reuses whichever profile was last open. Renaming a profile in
// Chrome therefore breaks routing with no error, so re-check these after any
// re-signin or fresh machine setup.
const WORK = "miren.dev";
const CTL = "chicagotoollibrary.org";
const PERSONAL = "phinze.com";

export default {
  // Which Zen space a URL lands in (e.g. mirendev links → Miren) is Zen's
  // Space Routing, declared in zen.nix, not a handler here.
  defaultBrowser: "Zen",

  options: {
    // Log all URL requests to console for debugging
    logRequests: false,
    hideIcon: true,
  },

  handlers: [
    {
      // Google Meet links - open in the Chrome profile for the account in
      // `authuser`, which MeetingBar stamps from the event's attendee entry
      // for you, falling back to the account the calendar is read through.
      // That only works with MeetingBar on its macOS Calendar data source,
      // which knows every account. Its Google Calendar API source holds one
      // account and stamps it on every event, shared calendars included.
      // Anything without a recognized authuser keeps going to Work.
      match: (url) =>
        url.host === "meet.google.com" || url.pathname?.startsWith("/meet/"),
      browser: (url) => {
        const authuser = url.searchParams.get("authuser") ?? "";
        let profile = WORK;
        if (authuser.endsWith("@chicagotoollibrary.org")) profile = CTL;
        else if (authuser === "phinze@phinze.com") profile = PERSONAL;
        return { name: "Google Chrome", profile };
      },
    },
    {
      // gcloud CLI OAuth - route work Google auth to the Chrome Work profile,
      // which is already signed into the work account. 32555940559 is the
      // fixed, public Google Cloud SDK OAuth client ID, so this only diverts
      // gcloud's own login flow; personal accounts.google.com visits stay put.
      match: (url) =>
        url.host === "accounts.google.com" &&
        url.searchParams.get("client_id")?.startsWith("32555940559"),
      browser: {
        name: "Google Chrome",
        profile: WORK,
      },
    },
    {
      // Chicago Tool Library OAuth - route Google auth flows hinting the CTL
      // org account to the Chrome CTL profile, which is signed into it.
      // Matches on login_hint (the account), so any CTL app's OAuth flow lands
      // in the right profile rather than the default browser.
      match: (url) =>
        url.host === "accounts.google.com" &&
        url.searchParams
          .get("login_hint")
          ?.endsWith("@chicagotoollibrary.org"),
      browser: {
        name: "Google Chrome",
        profile: CTL,
      },
    },
    {
      // Personal Google OAuth - route auth flows hinting the personal account
      // to the Chrome Personal profile, which is signed into it.
      match: (url) =>
        url.host === "accounts.google.com" &&
        url.searchParams.get("login_hint") === "phinze@phinze.com",
      browser: {
        name: "Google Chrome",
        profile: PERSONAL,
      },
    },
    {
      // Work Google OAuth - route auth flows hinting the work account to the
      // Chrome Work profile. Complements the gcloud client_id match above,
      // which covers gcloud's own flow (it often omits login_hint).
      match: (url) =>
        url.host === "accounts.google.com" &&
        url.searchParams.get("login_hint") === "paul@miren.dev",
      browser: {
        name: "Google Chrome",
        profile: WORK,
      },
    },
  ],

  rewrite: [
    {
      // Strip tracking parameters from Google URLs
      match: (url) => url.host?.endsWith("google.com"),
      url: (url) => {
        // Remove common tracking parameters
        const trackingParams = [
          "utm_source",
          "utm_medium",
          "utm_campaign",
          "utm_term",
          "utm_content",
          "gclid",
          "fbclid",
        ];
        trackingParams.forEach((param) => {
          url.searchParams.delete(param);
        });
        return url;
      },
    },
  ],
} satisfies FinickyConfig;
