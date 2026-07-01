// Finicky v4 configuration with TypeScript
// See: https://github.com/johnste/finicky/wiki/Configuration-(v4)

import type { FinickyConfig } from "/Applications/Finicky.app/Contents/Resources/finicky.d.ts";

export default {
  defaultBrowser: "Zen",

  options: {
    // Log all URL requests to console for debugging
    logRequests: false,
    hideIcon: true,
  },

  handlers: [
    {
      // Google Meet links - open in Chrome with Work profile
      match: (url) => {
        return (
          url.host === "meet.google.com" || url.pathname?.startsWith("/meet/")
        );
      },
      browser: {
        name: "Google Chrome",
        profile: "Work",
      },
    },
    {
      // gcloud CLI OAuth - route work Google auth to the Chrome Work profile,
      // which is already signed into the work account. 32555940559 is the
      // fixed, public Google Cloud SDK OAuth client ID, so this only diverts
      // gcloud's own login flow; personal accounts.google.com visits stay put.
      match: (url) =>
        url.host === "accounts.google.com" &&
        url.search?.client_id?.startsWith("32555940559"),
      browser: {
        name: "Google Chrome",
        profile: "Work",
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
          if (url.search) delete url.search[param];
        });
        return url;
      },
    },
  ],
} satisfies FinickyConfig;
