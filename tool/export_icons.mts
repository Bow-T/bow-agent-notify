/**
 * Xuất các icon "kẹo 3D" của web bow thành file SVG đứng riêng (tool/icons/<tên>.svg) để app dùng lại đúng hình.
 * Nguồn hình là `web/icons3d.ts` của repo bow-agent — hai repo không chung mã, nên mỗi khi bộ icon bên đó đổi thì
 * chạy lại:
 *
 *   node --import <bow-agent>/node_modules/tsx/dist/esm/index.mjs tool/export_icons.mts <bow-agent>/web/icons3d.ts
 *   tool/render_icons.sh        # SVG → PNG vào assets/ và icon của hai nền tảng
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

/** Hình app dùng — tên theo `ART` của icons3d.ts. */
const NAMES = ['agent', 'bell', 'shield', 'chat', 'success', 'error', 'bolt', 'warning', 'trash', 'clipboard', 'camera'];

const source = process.argv[2];
if (!source) throw new Error('Thiếu đường dẫn tới web/icons3d.ts của bow-agent.');
const { spriteMarkup } = (await import(pathToFileURL(resolve(source)).href)) as { spriteMarkup: () => string };
const sprite = spriteMarkup();
const defs = /<defs>(.*?)<\/defs>/s.exec(sprite)?.[1];
if (!defs) throw new Error('Không thấy <defs> trong sprite.');

const out = join(dirname(fileURLToPath(import.meta.url)), 'icons');
mkdirSync(out, { recursive: true });
const artOf = (name: string): string => {
  const art = new RegExp(`<symbol id="bic-i-${name}" viewBox="0 0 32 32">(.*?)</symbol>`, 's').exec(sprite)?.[1];
  if (!art) throw new Error(`Bộ icon của web không có hình "${name}".`);
  return art;
};
/** Chỉ giữ gradient mà đoạn hình này dùng. */
const defsFor = (art: string): string =>
  [...defs.matchAll(/<(linearGradient|radialGradient|clipPath) id="([^"]+)".*?<\/\1>/gs)].filter((m) => art.includes(`#${m[2]}`)).map((m) => m[0]).join('');
const save = (file: string, svg: string): void => {
  writeFileSync(join(out, file), `${svg}\n`);
  console.log(file);
};
/** Bóng đổ mềm như `.bow-ic-3d` của web. */
const shadow = (id: string, dy: number, blur: number, opacity: number): string =>
  `<filter id="${id}" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="${dy}" stdDeviation="${blur}" flood-color="#14285A" flood-opacity="${opacity}"/></filter>`;

for (const name of NAMES) {
  const art = artOf(name);
  // Khung nới 1 đơn vị mỗi phía cho bóng khỏi bị cắt.
  save(`${name}.svg`, `<svg xmlns="http://www.w3.org/2000/svg" viewBox="-1 -1 34 34"><defs>${defsFor(art)}${shadow('shadow', 0.7, 0.55, 0.3)}</defs><g filter="url(#shadow)">${art}</g></svg>`);
}

/*
 * LOGO của app = robot agent + chuông thông báo, ghép từ chính hai hình trên (khung 64×64): robot ở dưới-trái,
 * chuông nghiêng ở trên-phải, mép chuông chạm góc đầu robot.
 *  - logo_mark.svg: chỉ hình (nền trong suốt) — dùng trong app và làm lớp trước của icon thích ứng Android;
 *  - logo_adaptive.svg: cùng hình, thu vào vùng an toàn 66/108 của icon thích ứng Android (nền do Android vẽ);
 *  - logo.svg: hình trên nền Cực quang của theme kính, kèm hai vạch "đang reo" — icon app của iOS.
 */
const mark = `<g transform="translate(3 14) scale(1.55)">${artOf('agent')}</g><g transform="translate(34.5 1.5) scale(.9) rotate(16 16 16)">${artOf('bell')}</g>`;
const markDefs = defsFor(mark);
save('logo_mark.svg', `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><defs>${markDefs}${shadow('shadow', 1.2, 1, 0.3)}</defs><g filter="url(#shadow)">${mark}</g></svg>`);

save('logo_adaptive.svg', `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108"><defs>${markDefs}${shadow('shadow', 1.2, 1.1, 0.45)}</defs><g transform="translate(22 22)" filter="url(#shadow)">${mark}</g></svg>`);

const blob = (id: string, cx: string, cy: string, r: string, color: string, opacity: number): string =>
  `<radialGradient id="${id}" cx="${cx}" cy="${cy}" r="${r}"><stop offset="0" stop-color="${color}" stop-opacity="${opacity}"/><stop offset=".7" stop-color="${color}" stop-opacity="0"/></radialGradient>`;
const aurora = blob('aur-a', '6%', '0%', '78%', '#6260e8', 0.95) + blob('aur-b', '96%', '2%', '72%', '#0a84ff', 0.92) + blob('aur-c', '88%', '100%', '78%', '#bf5af2', 0.78) + blob('aur-d', '8%', '100%', '72%', '#30bed2', 0.72);
const fill = (paint: string): string => `<rect width="1024" height="1024" fill="${paint}"/>`;
const ring = (d: string): string => `<path d="${d}" fill="none" stroke="#fff" stroke-width="1.5" stroke-linecap="round" opacity=".8"/>`;
save(
  'logo.svg',
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><defs>${markDefs}${aurora}`
    + `<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="46"/></filter>`
    + `<filter id="drop" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="1.4" stdDeviation="1.6" flood-color="#000" flood-opacity=".45"/></filter></defs>`
    + fill('#0a0c1e') + fill('url(#aur-a)') + fill('url(#aur-b)') + fill('url(#aur-c)') + fill('url(#aur-d)')
    + `<ellipse cx="446" cy="620" rx="300" ry="270" fill="#935FF7" opacity=".5" filter="url(#glow)"/>`
    + `<g transform="translate(104 138) scale(12)"><g filter="url(#drop)">${mark}</g>${ring('M60.5 4.5 Q63.6 9 62.4 14.4')}${ring('M37.6 3.2 Q33.4 5.6 32.4 10.4')}</g></svg>`,
);
