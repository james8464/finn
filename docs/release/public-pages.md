# Finn public pages

The static files in [`../../site`](../../site) publish the [support](https://james8464.github.io/finn/support.html) and [privacy policy](https://james8464.github.io/finn/privacy.html) pages. The [12 October publication](https://github.com/james8464/finn/actions/runs/38241420611) succeeded; both live HTTPS pages displayed the optional speech details and the privacy page's updated effective date and **Reword comparison** label. The content follows the policy and support source in this directory. Keep both versions aligned with the exact app build.

The publisher and contact use the details supplied by James; the policy's effective date is 12 October 2026. Check the policy against the final signed release build. GitHub Pages uses **GitHub Actions** as its source; run the manual **Publish Finn support pages** workflow from `main` after content changes. The workflow rejects unresolved publication markers in the deployment files. Verify both public HTTPS URLs after each deployment. The Privacy screen and listing draft now contain the policy URL; it still needs to be entered in App Store Connect.

The site uses system typography, semantic HTML, and one stylesheet. It has no scripts, analytics, forms, or third-party assets.
