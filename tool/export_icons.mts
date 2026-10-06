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
const NAMES = ['agent', 'bell', 'shield', 'chat', 'success', 'error', 'bolt', 'warning', 'trash', 'camera', 'qr', 'layers', 'activity', 'gear', 'info'];

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
 * LOGO của app = "quả cầu agent": một quả cầu chàm bóng mang kính che + hai mắt xanh của agent, chuông thông báo tựa
 * ở góc trên-phải. Quả cầu vẽ ở đây (chỉ app dùng) bằng đúng cách dựng "bi" của bộ icon — bản sao sẫm lệch xuống làm
 * bề dày + thân đổ màu toả tròn `bic-r-indigo` — còn chuông lấy nguyên từ bộ icon. Khung gốc 32×32 của bộ icon; chuông
 * nhô ra ngoài khung nên các file dưới tự khai khung nhìn.
 *  - logo_mark.svg: chỉ hình (nền trong suốt) — dấu thương hiệu trong app;
 *  - logo_adaptive.svg: cùng hình, thu vào vùng an toàn (đường tròn 66/108) của icon thích ứng Android — nền do
 *    Android vẽ (res/drawable/ic_launcher_background.xml);
 *  - logo.svg: hình trên nền sáng — icon app của iOS.
 */
const INDIGO_LIP = '#3C47CF'; // PAL.indigo[2] của icons3d.ts
const eye = (cx: number): string => `<circle cx="${cx}" cy="17.62" r="2.06" fill="#7DF3FF"/><circle cx="${cx - 0.62}" cy="16.92" r=".7" fill="#fff"/>`;
const orb =
  `<circle cx="15" cy="19.1" r="11.8" fill="${INDIGO_LIP}"/><circle cx="15" cy="17.4" r="11.8" fill="url(#bic-r-indigo)"/>`
  + `<rect x="7" y="13.2" width="16" height="9.6" rx="4.42" fill="#1B1F5E"/>` + eye(10.52) + eye(19.48)
  + `<path d="M13.4 20.69 q1.6 .96 3.2 0" fill="none" stroke="#7DF3FF" stroke-width=".96" stroke-linecap="round"/>`
  + `<ellipse cx="9.6" cy="9.8" rx="2.8" ry="1.3" fill="#fff" opacity=".6" transform="rotate(-38 9.6 9.8)"/>`;
const mark = `${orb}<g transform="translate(17.6 -3.6) scale(.5) rotate(16 16 16)">${artOf('bell')}</g>`;
const markDefs = defsFor(mark);
// Hình chiếm x 3…34,5 và y −3,5…31 ⇒ khung vuông 37 đơn vị quanh tâm (18,75; 13,75).
save('logo_mark.svg', `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0.25 -4.75 37 37"><defs>${markDefs}${shadow('shadow', 0.8, 0.7, 0.3)}</defs><g filter="url(#shadow)">${mark}</g></svg>`);
// Điểm xa tâm nhất (đỉnh chuông) cách ~20,6 đơn vị; bán kính vùng an toàn là 33 ⇒ phóng 1,55 là còn dư lề.
save('logo_adaptive.svg', `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108"><defs>${markDefs}${shadow('shadow', 0.8, 0.8, 0.3)}</defs><g transform="translate(24.94 32.69) scale(1.55)" filter="url(#shadow)">${mark}</g></svg>`);

const blob = (id: string, cx: string, cy: string, color: string, opacity: number): string =>
  `<radialGradient id="${id}" cx="${cx}" cy="${cy}" r="70%"><stop offset="0" stop-color="${color}" stop-opacity="${opacity}"/><stop offset=".7" stop-color="${color}" stop-opacity="0"/></radialGradient>`;
const fill = (paint: string): string => `<rect width="1024" height="1024" fill="${paint}"/>`;
save(
  'logo.svg',
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><defs>${markDefs}`
    + `<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#DCE5FA"/></linearGradient>`
    + blob('pastel-a', '90%', '6%', '#B8C2FF', 0.7) + blob('pastel-b', '6%', '96%', '#A3F3E9', 0.6)
    + `<filter id="drop" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="1" stdDeviation="1" flood-color="#14285A" flood-opacity=".3"/></filter></defs>`
    + fill('url(#bg)') + fill('url(#pastel-a)') + fill('url(#pastel-b)')
    + `<g transform="translate(128 150) scale(24)" filter="url(#drop)">${mark}</g></svg>`,
);
