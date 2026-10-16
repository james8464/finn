import fs from "node:fs/promises";
import { Presentation, PresentationFile } from "@oai/artifact-tool";
const K = "/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16/keynote";
const scenes = JSON.parse(await fs.readFile(K + "/five-minute-scenes.json", "utf8"));
const p = Presentation.create({ slideSize: { width: 1920, height: 1080 } });
for (const s of scenes) {
  let slide = p.slides.add();
  slide.background.fill = s.bg;
  slide.images.add({
    blob: new Uint8Array(await fs.readFile(K + "/preview/" + String(s.number).padStart(2, "0") + ".png")),
    contentType: "image/png",
    alt: s.title,
    position: { left: 0, top: 0, width: 1920, height: 1080 },
  });
  slide.speakerNotes.text = s.notes;
}
await (await PresentationFile.exportPptx(p)).save(K + "/build/base.pptx");
console.log("Artifact Tool: ten-slide base and notes exported.");
