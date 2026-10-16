const fs = require("fs"),
  sharp = require("/Users/james/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp");
const R = "/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16",
  K = R + "/keynote";
const scenes = JSON.parse(fs.readFileSync(K + "/five-minute-scenes.json"));
(async () => {
  fs.mkdirSync(K + "/build/layers", { recursive: true });
  async function visit(n) {
    if (n.svg) {
      n.raster = "keynote/build/layers/" + n.key + ".png";
      await sharp(Buffer.from(n.svg))
        .png()
        .toFile(R + "/" + n.raster);
    }
    for (const c of n.children || []) await visit(c);
  }
  for (const s of scenes) for (const n of s.nodes) await visit(n);
  fs.writeFileSync(K + "/five-minute-scenes.json", JSON.stringify(scenes));
  console.log("Motion text layers prepared");
})();
