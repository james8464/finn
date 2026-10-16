import path from "node:path";
import { pathToFileURL } from "node:url";
const SK =
    "/Users/james/.codex/plugins/cache/openai-primary-runtime/presentations/26.1013.11914/skills/presentations",
  K = "/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16/keynote";
const { finalizePresentation } = await import(
  pathToFileURL(SK + "/container_tools/artifact_tool_utils.mjs").href
);
console.log(
  await finalizePresentation({
    workspaceDir: K,
    candidatePath: K + "/build/Finn-Five-Minutes-motion.pptx",
    finalPath: K + "/output/Finn-WWDC-5min-Polished.pptx",
    pythonExecutable:
      "/Users/james/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3",
    integrityValidatorPath: SK + "/container_tools/inspect_presentation_package_integrity.py",
    layoutValidatorPath: SK + "/container_tools/inspect_presentation_layout_geometry.py",
    layoutArgs: ["--expected-slide-size-emu", "18288000,10287000"],
    explicitTotalSlideCount: 10,
    requiredNativeTableOwnerSlides: [],
    requiredNativeChartOwnerSlides: [],
    verifyArtifactToolImport: true,
    receiptPath: K + "/build/wwdc-polished-validation.json",
  }),
);
