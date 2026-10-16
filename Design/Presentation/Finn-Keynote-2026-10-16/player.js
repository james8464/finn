const scenes = JSON.parse(document.getElementById("scene-data").textContent);
const video = document.querySelector("video");
const slideCounter = document.querySelector("#count");
const presenterNotes = document.querySelector("#notes");
let currentSlideIndex = 0;
let autoAdvance = true;

function showSlide(requestedIndex, shouldPlay = true) {
  currentSlideIndex = Math.max(0, Math.min(scenes.length - 1, requestedIndex));
  const scene = scenes[currentSlideIndex];
  const slideNumber = String(currentSlideIndex + 1).padStart(2, "0");

  video.src = currentSlideIndex === 0 ? "videos/finn-opening-film.mp4" : `keynote/media/${slideNumber}.mp4`;
  video.poster = `keynote/preview/${slideNumber}.png`;
  slideCounter.textContent = `${currentSlideIndex + 1} / ${scenes.length}`;

  const heading = document.createElement("h2");
  heading.textContent = scene.title;
  const notes = document.createElement("p");
  notes.textContent = scene.notes.split("Sources:")[0].split("Source:")[0];
  const timing = document.createElement("small");
  timing.textContent = `${scene.seconds}s · 5:00 total`;
  presenterNotes.replaceChildren(heading, notes, timing);
  location.hash = currentSlideIndex + 1;

  if (shouldPlay) {
    video.play().catch(() => {
      // Browsers may require a tap before starting playback with sound.
    });
  }
}

function togglePlayback() {
  if (video.paused) {
    video.play().catch(() => {});
  } else {
    video.pause();
  }
}

video.onended = () => {
  if (autoAdvance && currentSlideIndex < scenes.length - 1) {
    showSlide(currentSlideIndex + 1);
  }
};

document.querySelector("#go").onclick = () => {
  document.querySelector("#start").style.display = "none";
  showSlide(0);
};
document.querySelector("#prev").onclick = () => showSlide(currentSlideIndex - 1);
document.querySelector("#next").onclick = () => showSlide(currentSlideIndex + 1);
document.querySelector("#pause").onclick = togglePlayback;
document.querySelector("#replay").onclick = () => showSlide(currentSlideIndex);
document.querySelector("#note").onclick = () => presenterNotes.classList.toggle("open");
document.querySelector("#auto").onclick = (event) => {
  autoAdvance = !autoAdvance;
  event.target.textContent = autoAdvance ? "Auto advance on" : "Auto advance off";
};
document.querySelector("#full").onclick = () => document.documentElement.requestFullscreen();

addEventListener("keydown", (event) => {
  if (event.key === "ArrowRight") showSlide(currentSlideIndex + 1);
  if (event.key === "ArrowLeft") showSlide(currentSlideIndex - 1);
  if (event.key === " ") {
    event.preventDefault();
    togglePlayback();
  }
  if (event.key.toLowerCase() === "n") presenterNotes.classList.toggle("open");
});

const requestedSlide = Number(location.hash.slice(1) || 1);
showSlide(Number.isFinite(requestedSlide) ? requestedSlide - 1 : 0, false);
