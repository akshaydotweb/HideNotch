// Plausible analytics. The DMG download is hosted on GitHub, so it counts as an outbound link.

import { init } from "@plausible-analytics/tracker";

init({ domain: "hidenotch.app", outboundLinks: true });
