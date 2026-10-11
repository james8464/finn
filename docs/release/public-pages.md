# Plumb public pages

The static files in [`../../site`](../../site) publish the [support](https://james8464.github.io/hackathon-project/support.html) and [privacy policy](https://james8464.github.io/hackathon-project/privacy.html) pages. Both returned HTTPS 200 with the supplied publisher and contact details on 11 October 2026. The content follows the policy and support source in this directory. Keep both versions aligned with the exact app build.

The publisher, contact, and effective date are set to the details supplied by James on 11 October 2026. Check the policy against the final signed release build. GitHub Pages uses **GitHub Actions** as its source; run the manual **Publish Plumb support pages** workflow from `main` after content changes. The workflow rejects unresolved publication markers in the deployment files. Verify both public HTTPS URLs after each deployment. The Privacy screen and listing draft now contain the policy URL; it still needs to be entered in App Store Connect.

The site uses system typography, semantic HTML, and one stylesheet. It has no scripts, analytics, forms, or third-party assets.
