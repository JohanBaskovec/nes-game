// Banc de test sans écran : charge une ROM dans jsnes, joue une séquence
// d'entrées, sauvegarde des captures PNG et affiche des octets de RAM.
//
// Usage :
//   node run.mjs <rom.nes> [options]
//     --frames N            nombre d'images à émuler (défaut 120)
//     --input "F:+BTN,F:-BTN,..."  appuis (+) / relâchements (-) à l'image F
//                           BTN = A B SELECT START UP DOWN LEFT RIGHT
//     --shots "F1,F2,..."   images à capturer (PNG)
//     --out DIR             dossier des captures (défaut ./shots)
//     --ram "ADDR[:LEN],..." octets de RAM (hexa) à afficher à la fin
//     --watch "ADDR,..."    affiche ces octets à chaque capture
import fs from "node:fs";
import path from "node:path";
import { NES, Controller } from "jsnes";
import { PNG } from "pngjs";

const args = process.argv.slice(2);
if (args.length < 1) {
  console.error("usage: node run.mjs rom.nes [--frames N] [--input ...] [--shots ...]");
  process.exit(1);
}
const romPath = args[0];
const opt = { frames: 120, input: "", shots: "", out: "shots", ram: "", watch: "" };
for (let i = 1; i < args.length; i += 2) opt[args[i].replace(/^--/, "")] = args[i + 1];

const BTN = {
  A: Controller.BUTTON_A, B: Controller.BUTTON_B, SELECT: Controller.BUTTON_SELECT,
  START: Controller.BUTTON_START, UP: Controller.BUTTON_UP, DOWN: Controller.BUTTON_DOWN,
  LEFT: Controller.BUTTON_LEFT, RIGHT: Controller.BUTTON_RIGHT,
};

const events = new Map();
for (const tok of opt.input.split(",").filter(Boolean)) {
  const m = tok.trim().match(/^(\d+):([+-])(\w+)$/);
  if (!m) throw new Error("entrée invalide: " + tok);
  const f = +m[1];
  if (!events.has(f)) events.set(f, []);
  events.get(f).push([m[2] === "+", BTN[m[3]]]);
}
// Symboles : fichier .lbl (ld65 -Ln) à côté de la ROM.
const syms = {};
const lbl = romPath.replace(/\.nes$/, ".lbl");
if (fs.existsSync(lbl)) {
  for (const line of fs.readFileSync(lbl, "utf8").split("\n")) {
    const m = line.match(/^al ([0-9A-F]+) \.(\S+)/i);
    if (m) syms[m[2]] = parseInt(m[1], 16);
  }
}
const addr = (a) => (a in syms ? syms[a] : parseInt(a, 16));
const shots = new Set(opt.shots.split(",").filter(Boolean).map(Number));
// --poke "sym=val,..." : valeurs forcées en RAM avant chaque trame (tests)
const pokes = (opt.poke || "").split(",").filter(Boolean).map((t) => {
  const [a, v] = t.split("=");
  return [addr(a), parseInt(v, 16)];
});
// --set "F:sym=val,..." : écriture unique en RAM avant la trame F (tests)
const sets = new Map();
for (const t of (opt.set || "").split(",").filter(Boolean)) {
  const m = t.match(/^(\d+):(\w+)=([0-9A-Fa-f]+)$/);
  if (!m) throw new Error("--set invalide: " + t);
  if (!sets.has(+m[1])) sets.set(+m[1], []);
  sets.get(+m[1]).push([addr(m[2]), parseInt(m[3], 16)]);
}
const watchNames = opt.watch.split(",").filter(Boolean);
const watch = watchNames.map(addr);

let lastFrame = null;
const nes = new NES({
  onFrame: (buf) => { lastFrame = buf; },
  onAudioSample: null,
  emulateSound: false,
});
const rom = fs.readFileSync(romPath);
nes.loadROM(rom.toString("binary"));

fs.mkdirSync(opt.out, { recursive: true });
const mem = () => nes.cpu.mem;
const hex = (v, n = 2) => v.toString(16).toUpperCase().padStart(n, "0");

function savePng(file) {
  const png = new PNG({ width: 256, height: 240 });
  for (let i = 0; i < 256 * 240; i++) {
    const c = lastFrame[i];
    png.data[i * 4] = c & 0xff;
    png.data[i * 4 + 1] = (c >> 8) & 0xff;
    png.data[i * 4 + 2] = (c >> 16) & 0xff;
    png.data[i * 4 + 3] = 255;
  }
  fs.writeFileSync(file, PNG.sync.write(png));
}

// --profile N : mesure les cycles CPU à partir de la trame N
//   ppu  = de l'entrée dans la NMI à la fin du travail PPU (doit tenir dans le VBlank)
//   nmi  = NMI complète (avec le son)
//   work = travail de la boucle principale pour une trame (hors NMI)
const prof = { on: false, ppu: 0, nmi: 0, work: 0, frames: 0, workFrame: 0, over: 0, cur: 0 };
if (opt.profile !== undefined) {
  const A = { nmi: syms.nmi, audio: syms.nmi_audio, exit: syms.nmi_exit, loop: syms.main_loop, wait: syms.main_wait };
  const cpu = nes.cpu;
  const orig = cpu.emulate.bind(cpu);
  let nmiStart = -1, nmiInFrame = 0, loopStart = -1, inWait = false;
  cpu.emulate = () => {
    const pc = cpu.REG_PC;
    const c = cpu.cycles;
    if (prof.on) {
      if (pc === A.nmi) nmiStart = c;
      else if (pc === A.audio && nmiStart >= 0) prof.ppu = Math.max(prof.ppu, c - nmiStart);
      else if (pc === A.exit && nmiStart >= 0) {
        prof.nmi = Math.max(prof.nmi, c - nmiStart);
        if (loopStart >= 0 && !inWait) nmiInFrame += c - nmiStart;
        nmiStart = -1;
      } else if (pc === A.loop) { loopStart = c; nmiInFrame = 0; inWait = false; }
      else if (pc === A.wait && !inWait && loopStart >= 0) {
        const w = c - loopStart - nmiInFrame;
        if (w > prof.work) { prof.work = w; prof.workFrame = prof.cur; }
        if (w > 26500) prof.over++;
        prof.frames++;
        inWait = true;
      }
    }
    return orig();
  };
}

// --breakdown F : temps passé dans chaque étape de game_update à la trame F
const steps = ["player_update", "camera_update", "spawn_update", "ninja_spawner", "update_enemies",
  "update_pbullets", "update_ebullets", "update_particles", "combo_update", "level_end_check",
  "hud_update", "refresh_palette", "build_oam", "draw_player", "draw_ebullets", "draw_enemies",
  "draw_pbullets", "draw_particles", "oam_finish", "compute_scroll", "main_wait"];
const bd = [];
if (opt.breakdown !== undefined) {
  const map = new Map(steps.filter((s) => s in syms).map((s) => [syms[s], s]));
  const cpu = nes.cpu;
  const orig = cpu.emulate.bind(cpu);
  cpu.emulate = () => {
    if (prof.cur === +opt.breakdown) {
      const n = map.get(cpu.REG_PC);
      if (n && (bd.length === 0 || bd[bd.length - 1][0] !== n)) bd.push([n, cpu.cycles]);
    }
    return orig();
  };
}

const total = +opt.frames;
for (let f = 0; f < total; f++) {
  for (const [down, b] of events.get(f) || []) {
    if (down) nes.buttonDown(1, b); else nes.buttonUp(1, b);
  }
  if (opt.profile !== undefined && f === +opt.profile) prof.on = true;
  prof.cur = f;
  for (const [a, v] of pokes) mem()[a] = v;
  for (const [a, v] of sets.get(f) || []) mem()[a] = v;
  nes.frame();
  if (opt.every && f % +opt.every === 0) shots.add(f);
  if (shots.has(f)) {
    const file = path.join(opt.out, `f${String(f).padStart(5, "0")}.png`);
    savePng(file);
    const w = watch.map((a, i) => `${watchNames[i]}=${hex(mem()[a])}`).join(" ");
    console.log(`capture ${file} ${w}`);
  }
}

if (opt.profile !== undefined) {
  console.log(`profil (${prof.frames} trames) : NMI-PPU max ${prof.ppu} cycles (VBlank ~2270),` +
    ` NMI max ${prof.nmi}, travail max ${prof.work} cycles à la trame ${prof.workFrame}, ${prof.over} trames > 26500`);
}

for (let i = 0; i + 1 < bd.length; i++) {
  console.log(`  ${bd[i][0].padEnd(18)} ${bd[i + 1][1] - bd[i][1]}`);
}

// --nt 0|1 : affiche la table de noms en texte (tuiles de police -> ASCII)
if (opt.nt !== undefined) {
  const base = 0x2000 + 0x400 * +opt.nt;
  for (let y = 0; y < 30; y++) {
    let line = "";
    for (let x = 0; x < 32; x++) {
      const t = nes.ppu.vramMem[base + y * 32 + x];
      line += t >= 0x20 && t < 0x60 ? String.fromCharCode(t) : t === 0 ? "." : "#";
    }
    console.log(String(y).padStart(2) + " " + line);
  }
}

for (const tok of opt.ram.split(",").filter(Boolean)) {
  const [a, l] = tok.split(":");
  const start = addr(a), len = l ? parseInt(l, 10) : 1;
  const bytes = [];
  for (let i = 0; i < len; i++) bytes.push(hex(mem()[start + i]));
  console.log(`${a} ($${hex(start, 4)}): ${bytes.join(" ")}`);
}
