# LearningApp public discovery website — zero-cost foundation

This is a separate, lightweight static website for publicly reviewed editorial
content. It does not modify the existing Flutter Learn / Library / Progress
experience, its routes, or protected learner data.

## This milestone

- Pure Python 3 generator without external packages, network requests,
  database connections, user records, AI calls, trackers or ad scripts.
- Semantic HTML, responsive CSS, meta descriptions, canonical URLs,
  OpenGraph/Twitter metadata, WebPage/WebSite/Breadcrumb schema,
  accessible navigation, an XML sitemap, robots and a 404 page.
- Strict editorial approval gate. All initial pages are DRAFT. An indexable
  export is refused until the owner confirms and reviews the homepage.
- The preview output contains editorial drafts and is universally marked
  noindex,nofollow with a robots disallow. NEVER deploy preview output.
- No Google QAPage or FAQPage claims for curated editorial content.
- No generated FAQ mass export, protected answer banks or private accounts.

## Offline local preview

From the repository root:

~~~sh
python3 tool/build_public_site.py --preview \
  --origin https://www.example.test \
  --app-origin https://app.example.test \
  --out build/public-preview
python3 -m http.server 8765 --directory build/public-preview
~~~

Then visit http://localhost:8765/. The example.test domain is an
illustrative test value, not a claim of domain ownership.

## Publishing only after owner review

1. Verify ownership, DNS and TLS for the chosen public domain. The
   illustrative www.learningapp.io is NOT assumed to be configured.
2. Approve exact wording, links, factual sources and compliance information
   for each editorial page. Change only approved pages to status=published,
   review.owner_approved=true, add a real review date and source references.
3. Generate a brand-new production candidate (does not deploy):

~~~sh
python3 tool/build_public_site.py \
  --origin https://YOUR-VERIFIED-PUBLIC-DOMAIN \
  --app-origin https://app.learningapp.io \
  --out build/public-site
~~~

4. Host build/public-site as a separate static site, not within Flutter's
   build/web or its catchall Firebase rewrite. Static paths must give real HTTP
   200 for published pages, 404 for unknown/draft pages, and allow proper
   canonical/OG previews without JavaScript hydration. Provider selection and
   free-tier limits require independent review before deployment.
5. Test the deployed domain's DNS, HTTPS, HTML 200/404, unique title/H1, sitemap,
   robots, canonicals, social preview, keyboard access, mobile layout, redirects,
   accessibility and absence of learner/draft data. Submit the sitemap only
   after successful real-domain validation.

The existing Flutter web/sitemap.xml mentions some paths such as /faqs and
/catalog which the current router does not expose as corresponding public HTML.
That separate, already-deployed crawler configuration needs its own cutover
review. This PR does NOT silently change existing production routes or hosting.

The builder intentionally omits lastmod unless an authoritative publication
change log is added, and it does not invent reviews, course accreditation,
prices, issuer endorsements or exam outcomes.

## Tests

~~~sh
python3 -m unittest discover -s tool/tests -p 'test_public_site_build.py' -v
~~~

Tests cover editorial approval, noindex previews, escaping, publication-only
sitemap, reserved URLs, output safety and local real HTTP 200/404. GitHub CI
also builds a disposable preview using only Python standard-library tools.

## Zero-cost and feature governance

Site generation costs nothing extra. Static hosting can be within a free tier
but domain renewal and provider quotas can still cost money. No live deployment,
donation integration, ad account or sitewide feature activation is authorized by
this commit. A future launch must pass the master plan's release approval gates.

## Existing seed FAQ SEO compatibility correction

The existing Flutter SeoMetadataService previously labeled fixed seed FAQs as QAPage and returned index/follow metadata with unverified app-host /faqs URLs. This milestone changes its structured data to plain WebPage, removes unverified URLs and vote/rich-result claims, and marks those app-host previews noindex until actual crawlable public HTML is released. The legacy Dart method name remains a deprecated compatibility wrapper so existing consumers are not removed.

## Emergency stand-down artifact (not an instant remote switch)

A no-content fallback artifact can be generated with:

~~~sh
python3 tool/build_public_site.py --origin https://YOUR-VERIFIED-PUBLIC-DOMAIN --out build/public-emergency --emergency-off
~~~

This generates only a noindex maintenance page, empty sitemap, robots disallow, and a noindex 404. It does NOT deploy anything or force a static provider to return HTTP 503/410, clear caches, or change DNS. The selected hosting provider must support a tested atomic rollback/stand-down and cache purge procedure, with independent owner authorization. Learner app routes and protected data remain unaffected. See the host runbook for launch requirements.
