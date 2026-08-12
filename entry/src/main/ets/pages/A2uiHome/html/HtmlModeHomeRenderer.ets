import { HtmlHomeDocument } from './HtmlHomeTypes';
import { APP_LOGO_BILIBILI, APP_LOGO_YOUTUBE } from './AppLogoDataUri';
import { personaAvatarDataUri } from './PersonaAvatarDataUri';

type HtmlModeTextValue = Object | string | number | boolean | null | undefined;

interface HtmlModeHomeDocumentWithBusy extends HtmlHomeDocument {
  isBusy?: boolean;
  personaAvatarDataUri?: string;
}

const MODE_HOME_CSS: string = `
:root {
  color-scheme: light;
  --paper: #f5f2ee;
  --panel: rgba(255, 255, 255, 0.88);
  --panel-strong: #ffffff;
  --ink: #211b17;
  --ink-soft: #493f38;
  --muted: #7a6e64;
  --line: rgba(33, 27, 23, 0.12);
  --line-strong: rgba(23, 18, 13, 0.2);
  --accent: #995f4c;
  --accent-soft: rgba(153, 95, 76, 0.13);
  --good: #2f7a4f;
  --good-soft: rgba(47, 122, 79, 0.12);
  --youtube: #ad4a3f;
  --youtube-soft: rgba(173, 74, 63, 0.13);
  --bilibili: #b66783;
  --bilibili-soft: rgba(182, 103, 131, 0.15);
  --home: #397a55;
  --home-soft: rgba(57, 122, 85, 0.12);
  --dnd: #6f5bd6;
  --dnd-soft: rgba(111, 91, 214, 0.13);
  --mail: #2d78c4;
  --mail-soft: rgba(45, 120, 196, 0.13);
  --shadow: 0 18px 42px rgba(37, 24, 13, 0.13);
}
* { box-sizing: border-box; }
body {
  margin: 0;
  min-height: 100vh;
  background:
    linear-gradient(180deg, rgba(255, 250, 241, 0.78) 0%, rgba(248, 242, 232, 0.98) 58%, var(--paper) 100%),
    var(--paper);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", "Helvetica Neue", Arial, sans-serif;
  letter-spacing: 0;
  -webkit-font-smoothing: antialiased;
}
button { font: inherit; cursor: pointer; }
button:disabled { cursor: default; opacity: 0.5; }
h1, h2, h3, p { margin: 0; }
img { display: block; }
.mode-shell {
  width: min(100%, 820px);
  min-height: 100vh;
  margin: 0 auto;
  padding-bottom: calc(92px + env(safe-area-inset-bottom, 0px));
}
.mode-hero {
  position: relative;
  min-height: 240px;
  padding: 24px 16px 20px;
  overflow: hidden;
  background: #21170f;
  isolation: isolate;
}
.mode-hero::before {
  content: "";
  position: absolute;
  inset: 0;
  z-index: -2;
  background: linear-gradient(135deg, #2b2017, #5d3d26 52%, #243947);
  background-size: cover;
  background-position: center;
  transform: scale(1.12);
}
.mode-hero::after {
  content: "";
  position: absolute;
  inset: 0;
  z-index: -1;
  background:
    linear-gradient(180deg, rgba(18, 13, 9, 0.06) 0%, rgba(18, 13, 9, 0.28) 44%, rgba(248, 242, 232, 0.98) 100%),
    linear-gradient(90deg, rgba(248, 242, 232, 0.88) 0%, rgba(248, 242, 232, 0.48) 48%, rgba(248, 242, 232, 0.18) 100%);
}
.mode-hero-grid {
  position: relative;
  z-index: 1;
  display: flex;
  min-height: 200px;
  align-items: flex-end;
}
.mode-hero-copy {
  max-width: 620px;
}
.mode-kicker {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  border: 1px solid rgba(23, 18, 13, 0.14);
  border-radius: 999px;
  padding: 7px 10px;
  background: rgba(255, 250, 241, 0.84);
  color: var(--muted);
  font-size: 12px;
  font-weight: 820;
  line-height: 1;
  backdrop-filter: blur(18px);
  box-shadow: 0 10px 28px rgba(37, 24, 13, 0.08);
}
.mode-hero h1 {
  margin-top: 14px;
  max-width: 10em;
  overflow-wrap: anywhere;
  font-size: 28px;
  line-height: 1.04;
  font-weight: 860;
}
.mode-hero p {
  margin-top: 10px;
  max-width: 32em;
  color: rgba(23, 18, 13, 0.76);
  font-size: 12px;
  line-height: 1.55;
  overflow-wrap: anywhere;
}
.mode-hero-stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 8px;
  max-width: 520px;
  margin-top: 14px;
}
.mode-stat {
  min-height: 60px;
  border: 1px solid rgba(23, 18, 13, 0.1);
  border-radius: 16px;
  padding: 10px;
  background: rgba(255, 250, 241, 0.76);
  backdrop-filter: blur(16px);
}
.mode-stat b {
  display: block;
  color: var(--ink);
  font-size: 18px;
  line-height: 1;
}
.mode-stat span {
  display: block;
  margin-top: 7px;
  color: var(--muted);
  font-size: 11px;
  font-weight: 760;
  line-height: 1.1;
}
.mode-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 12px;
  padding: 14px 14px 8px;
}
.mode-card {
  --source-accent: var(--accent);
  --source-soft: var(--accent-soft);
  --card-bg: var(--panel-strong);
  position: relative;
  overflow: hidden;
  border: 1px solid rgba(23, 18, 13, 0.1);
  border-radius: 16px;
  padding: 0;
  background:
    linear-gradient(135deg, var(--source-soft), rgba(255, 250, 241, 0) 54%),
    var(--card-bg);
  box-shadow: 0 8px 22px rgba(37, 24, 13, 0.08);
}
.mode-card[data-source="bilibili"] {
  --source-accent: var(--bilibili);
  --source-soft: var(--bilibili-soft);
}
.mode-card[data-source="youtube"] {
  --source-accent: var(--youtube);
  --source-soft: var(--youtube-soft);
}
.mode-card[data-source="home"] {
  --source-accent: var(--home);
  --source-soft: var(--home-soft);
}
.mode-card[data-source="dnd"] {
  --source-accent: var(--dnd);
  --source-soft: var(--dnd-soft);
}
.mode-card[data-source="mail"] {
  --source-accent: var(--mail);
  --source-soft: var(--mail-soft);
}
.mode-card::before {
  content: "";
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  background: var(--source-accent);
}
.mode-card-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 14px 4px;
}
.mode-card.is-collapsible .mode-card-head {
  align-items: center;
  min-height: 58px;
  padding-bottom: 12px;
  cursor: pointer;
}
.mode-card-head-tools {
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  gap: 7px;
}
.mode-card-toggle {
  display: grid;
  place-items: center;
  width: 26px;
  height: 26px;
  padding: 0;
  border: 1px solid rgba(23, 18, 13, 0.1);
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.82);
  color: var(--source-accent);
  font-size: 17px;
  line-height: 1;
}
.mode-card-body {
  overflow: hidden;
}
.mode-card.is-collapsible:not(.is-expanded) .mode-card-body {
  max-height: 0;
  opacity: 0;
  pointer-events: none;
}
.mode-card.is-collapsible.is-expanded .mode-card-body {
  max-height: 1200px;
  opacity: 1;
  pointer-events: auto;
}
.mode-card.is-collapsible:not(.is-expanded) .mode-card-head p {
  overflow: hidden;
  max-width: 36em;
  white-space: nowrap;
  text-overflow: ellipsis;
}
.mode-card-head h3 {
  min-width: 0;
  overflow-wrap: anywhere;
  color: var(--ink);
  font-size: 14px;
  line-height: 1.22;
  font-weight: 820;
}
.mode-card-head p {
  margin-top: 7px;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.mode-badge {
  flex: 0 0 auto;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  border-radius: 999px;
  padding: 5px 8px 5px 5px;
  border: 1px solid rgba(23, 18, 13, 0.08);
  background: var(--source-soft);
  color: var(--source-accent);
  font-size: 11px;
  font-weight: 820;
  line-height: 1;
  white-space: nowrap;
}
.mode-badge img {
  width: 17px;
  height: 17px;
  border-radius: 5px;
  object-fit: contain;
}
.mode-card-player {
  position: relative;
  overflow: hidden;
  border-radius: 12px;
  margin: 8px 14px 0;
  aspect-ratio: 16 / 9;
  background: #080604;
}
.mode-card-player iframe {
  display: block;
  width: 100%;
  height: 100%;
  border: 0;
}
.mode-rows {
  display: grid;
  gap: 5px;
  padding: 8px 14px 2px;
}
.mode-row {
  display: grid;
  grid-template-columns: 72px minmax(0, 1fr);
  gap: 8px;
  align-items: start;
  border: 1px solid rgba(23, 18, 13, 0.07);
  border-radius: 10px;
  padding: 7px 9px;
  background: rgba(255, 250, 241, 0.64);
}
.mode-row .label {
  color: var(--muted);
  font-size: 11px;
  font-weight: 780;
  line-height: 1.35;
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
}
.mode-row .value {
  color: var(--ink-soft);
  font-size: 12px;
  font-weight: 650;
  line-height: 1.4;
  overflow-wrap: anywhere;
}
.mode-card-action {
  margin: 8px 14px 12px;
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.mode-card-action .mode-btn {
  min-width: 0;
  border: 1px solid rgba(23, 18, 13, 0.1);
  border-radius: 999px;
  min-height: 30px;
  padding: 6px 12px;
  font-size: 12px;
  background: rgba(255, 250, 241, 0.78);
  color: var(--ink);
  font-weight: 700;
  white-space: nowrap;
  overflow-wrap: anywhere;
}
.mode-card-action .mode-btn.primary {
  border-color: var(--source-accent);
  color: var(--source-accent);
  background: var(--source-soft);
}
.mode-card-action .mode-btn.danger {
  border-color: rgba(176, 74, 66, 0.4);
  color: #b04a42;
  background: rgba(176, 74, 66, 0.08);
}
.mode-card-action .mode-btn:active { transform: scale(0.98); }
.mode-empty {
  margin: 14px;
  border: 1px dashed var(--line);
  border-radius: 20px;
  padding: 18px;
  background: rgba(255, 250, 241, 0.72);
  color: var(--muted);
  font-size: 13px;
  line-height: 1.5;
}
.mode-card[data-source="home"] .mode-rows,
.mode-card[data-source="dnd"] .mode-rows {
  padding-top: 5px;
}
.mode-card[data-source="home"] .mode-row,
.mode-card[data-source="dnd"] .mode-row {
  border: 0;
  background: transparent;
  padding: 3px 0;
}
.mode-card[data-source="home"] .mode-card-action .mode-btn {
  min-width: 62px;
  border-radius: 9px;
}
.mode-card[data-source="home"] .mode-card-action .mode-btn.primary {
  color: #fff;
  background: var(--home);
}
.mode-card[data-source="home"] .mode-card-action .mode-btn.danger {
  color: #fff;
  background: #b04a42;
}
.mode-card[data-source="dnd"] {
  max-width: 420px;
}
@media (min-width: 720px) {
  .mode-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .mode-hero { min-height: 260px; }
}
@media (max-width: 360px) {
  .mode-hero h1 { font-size: 31px; }
  .mode-hero-stats { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
`.trim();

const MODE_HOME_JS: string = `
(function () {
  var node = document.getElementById('home-data');
  var data = {};
  try { data = JSON.parse(node && node.textContent ? node.textContent : '{}') || {}; } catch (error) { data = {}; }
  var app = document.getElementById('app');
  if (!app) { return; }
  var isBusy = text(data.isBusy).toLowerCase() === 'true';
  function text(value) { return value === undefined || value === null ? '' : String(value); }
  function list(value) { return Array.isArray(value) ? value : []; }
  function trim(value) { return text(value).replace(/^\\s+|\\s+$/g, ''); }
  function add(parent, tag, className, value) {
    var el = document.createElement(tag);
    if (className) { el.className = className; }
    if (value !== undefined && value !== null && text(value).length > 0) { el.textContent = text(value); }
    parent.appendChild(el);
    return el;
  }
  function metric(block, labels) {
    var items = list(block && block.metrics).concat(list(block && block.rows));
    for (var i = 0; i < items.length; i += 1) {
      var label = text(items[i] && items[i].label);
      if (labels.indexOf(label) >= 0) { return text(items[i] && items[i].value); }
    }
    return '';
  }
  function sourceOf(block) {
    var raw = [text(block.source), text(block.title), metric(block, ['source', 'toolName'])].join(' ').toLowerCase();
    if (raw.indexOf('youtube') >= 0 || raw.indexOf('youtu.be') >= 0) { return 'youtube'; }
    if (raw.indexOf('bilibili') >= 0 || raw.indexOf('哔哩哔哩') >= 0 || raw.indexOf('b站') >= 0 || raw.indexOf('b 站') >= 0) { return 'bilibili'; }
    if (raw.indexOf('智能家电') >= 0 || raw.indexOf('家居') >= 0 || raw.indexOf('bedroom') >= 0 || raw.indexOf('curtain') >= 0) { return 'home'; }
    if (raw.indexOf('勿扰') >= 0 || raw.indexOf('dnd') >= 0 || raw.indexOf('not disturb') >= 0) { return 'dnd'; }
    if (raw.indexOf('邮件') >= 0 || raw.indexOf('邮箱') >= 0 || raw.indexOf('mail') >= 0) { return 'mail'; }
    return 'generic';
  }
  function sourceLabel(key) {
    if (key === 'bilibili') { return 'B 站'; }
    if (key === 'youtube') { return 'YouTube'; }
    if (key === 'home') { return '智能家电'; }
    if (key === 'dnd') { return '勿扰'; }
    if (key === 'mail') { return '邮件'; }
    return '工具';
  }
  function sourceLogoUrl(key) {
    if (key === 'bilibili') { return '${APP_LOGO_BILIBILI}'; }
    if (key === 'youtube') { return '${APP_LOGO_YOUTUBE}'; }
    return '';
  }
  function sourceShort(key) {
    if (key === 'bilibili') { return 'B'; }
    if (key === 'youtube') { return 'YT'; }
    if (key === 'home') { return '家'; }
    if (key === 'dnd') { return '扰'; }
    if (key === 'mail') { return '邮'; }
    return '具';
  }
  function isAllowedMediaEmbedUrl(url) {
    var raw = text(url);
    return raw.indexOf('https://www.youtube.com/embed/') === 0 ||
      raw.indexOf('https://player.bilibili.com/player.html?') === 0;
  }
  function playable(block) {
    return !!(block && block.mediaEmbed && isAllowedMediaEmbedUrl(block.mediaEmbed.embedUrl));
  }
  function rowsOf(block) {
    return list(block && block.rows).concat(list(block && block.metrics)).filter(function (item) {
      var label = text(item && item.label).toLowerCase();
      return text(item && item.label).length > 0 && text(item && item.value).length > 0 &&
        label !== 'toolname' && label !== 'watch url' && label !== 'bvid' && label !== 'video id';
    });
  }
  function actionsOf(block) {
    return list(block && block.actions).filter(function (action) {
      return text(action && (action.label || action.id)).length > 0;
    });
  }
  function shouldCollapse(block, key) {
    return playable(block) || rowsOf(block).length > 2 || actionsOf(block).length > 1 || key === 'mail';
  }
  function expansionKey(block, index) {
    return 'mode-card-expanded-' + text(block && block.id || index);
  }
  function readExpanded(key) {
    try { return window.sessionStorage && window.sessionStorage.getItem(key) === '1'; } catch (error) { return false; }
  }
  function saveExpanded(key, expanded) {
    try { if (window.sessionStorage) { window.sessionStorage.setItem(key, expanded ? '1' : '0'); } } catch (error) {}
  }
  function isGenericTitle(value) {
    var raw = trim(value);
    return raw.length === 0 || raw === '动态工具结果' || raw === '工具结果' || raw === '任务结果';
  }
  function heroTitle() {
    var raw = trim(data.title);
    if (isGenericTitle(raw)) { return '个人模式'; }
    return raw;
  }
  function heroSubtitle() {
    var subtitle = trim(data.subtitle);
    if (subtitle.length > 0 && !isGenericTitle(subtitle)) { return subtitle; }
    return '一个模式，一次触达，实时反馈每个任务的执行结果。';
  }
  function postAction(action) {
    if (isBusy || !action || text(action && action.label).length === 0) { return; }
    try {
      if (window.AIPhoneHome && typeof window.AIPhoneHome.postAction === 'function') {
        window.AIPhoneHome.postAction(JSON.stringify({
          id: text(action.id),
          label: text(action.label),
          prompt: text(action.prompt),
          variant: text(action.variant),
          kind: text(action.kind),
          sourceComponentId: text(action.sourceComponentId),
          args: action.args || {}
        }));
      }
    } catch (error) {}
  }
  function renderPlayer(parent, block, className) {
    var media = block && block.mediaEmbed ? block.mediaEmbed : {};
    var player = add(parent, 'div', className || 'mode-player');
    if (playable(block)) {
      var iframe = document.createElement('iframe');
      iframe.title = text(media.title) || text(block && block.title) || 'mode player';
      iframe.setAttribute('loading', 'lazy');
      iframe.setAttribute('allowfullscreen', 'true');
      iframe.setAttribute('allow', 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share');
      iframe.setAttribute('referrerpolicy', 'origin-when-cross-origin');
      iframe.src = text(media.embedUrl);
      player.appendChild(iframe);
    }
    return player;
  }
  function addHeroStat(parent, label, value) {
    var stat = add(parent, 'div', 'mode-stat');
    add(stat, 'b', '', value);
    add(stat, 'span', '', label);
  }
  function sourceCounts() {
    var counts = { bilibili: 0, youtube: 0, home: 0, dnd: 0, mail: 0, other: 0 };
    list(data.blocks).forEach(function (block) {
      var key = sourceOf(block);
      if (counts[key] === undefined) { key = 'other'; }
      counts[key] += 1;
    });
    return counts;
  }

  app.textContent = '';
  var shell = add(app, 'main', 'mode-shell');
  var hero = add(shell, 'header', 'mode-hero');
  var heroGrid = add(hero, 'div', 'mode-hero-grid');
  var heroCopy = add(heroGrid, 'div', 'mode-hero-copy');
  var kicker = add(heroCopy, 'div', 'mode-kicker');
  add(kicker, 'span', '', '个人模式 · 实时任务');
  add(heroCopy, 'h1', '', heroTitle());
  add(heroCopy, 'p', '', heroSubtitle());
  var counts = sourceCounts();
  var stats = add(heroCopy, 'div', 'mode-hero-stats');
  addHeroStat(stats, '任务', String(list(data.blocks).length));
  addHeroStat(stats, '音乐', String(counts.bilibili + counts.youtube));
  addHeroStat(stats, '家电', String(counts.home));
  addHeroStat(stats, '勿扰', String(counts.dnd));

  var grid = add(shell, 'section', 'mode-grid');
  var blocks = list(data.blocks);
  if (blocks.length === 0) {
    add(grid, 'div', 'mode-empty', '当前模式下暂无可显示的执行结果。');
  }
  blocks.forEach(function (block, index) {
    var key = sourceOf(block);
    var card = add(grid, 'article', 'mode-card');
    card.setAttribute('data-source', key);
    var collapsible = shouldCollapse(block, key);
    var stateKey = expansionKey(block, index);
    if (collapsible) { card.className += ' is-collapsible'; }
    if (collapsible && readExpanded(stateKey)) { card.className += ' is-expanded'; }
    var head = add(card, 'div', 'mode-card-head');
    var copy = add(head, 'div');
    add(copy, 'h3', '', text(block.title) || sourceLabel(key));
    if (text(block.subtitle).length > 0) { add(copy, 'p', '', block.subtitle); }
    var headTools = add(head, 'div', 'mode-card-head-tools');
    var badge = add(headTools, 'span', 'mode-badge');
    var logoUrl = sourceLogoUrl(key);
    if (logoUrl.length > 0) { add(badge, 'img').src = logoUrl; }
    add(badge, 'span', '', sourceLabel(key));
    var toggle = null;
    if (collapsible) {
      toggle = add(headTools, 'button', 'mode-card-toggle', card.className.indexOf('is-expanded') >= 0 ? '×' : '+');
      toggle.type = 'button';
      toggle.setAttribute('aria-label', card.className.indexOf('is-expanded') >= 0 ? '收起卡片' : '展开卡片');
    }
    var body = add(card, 'div', 'mode-card-body');
    if (playable(block)) { renderPlayer(body, block, 'mode-card-player'); }
    var rows = rowsOf(block);
    if (rows.length > 0) {
      var rowsEl = add(body, 'div', 'mode-rows');
      rows.forEach(function (row) {
        var r = add(rowsEl, 'div', 'mode-row');
        add(r, 'div', 'label', row.label);
        add(r, 'div', 'value', row.value);
      });
    }
    var actions = actionsOf(block);
    if (actions.length > 0) {
      var actionRow = add(body, 'div', 'mode-card-action');
      actions.forEach(function (action) {
        var btn = add(actionRow, 'button', 'mode-btn ' + text(action.variant && action.variant !== 'secondary' ? action.variant : ''));
        btn.type = 'button';
        btn.textContent = text(action.label || action.id);
        btn.disabled = isBusy;
        btn.addEventListener('click', function (event) { event.stopPropagation(); postAction(action); });
      });
    }
    if (collapsible) {
      var setExpanded = function (expanded) {
        if (expanded) { card.classList.add('is-expanded'); } else { card.classList.remove('is-expanded'); }
        toggle.textContent = expanded ? '×' : '+';
        toggle.setAttribute('aria-label', expanded ? '收起卡片' : '展开卡片');
        saveExpanded(stateKey, expanded);
      };
      head.addEventListener('click', function () { setExpanded(!card.classList.contains('is-expanded')); });
      toggle.addEventListener('click', function (event) {
        event.stopPropagation();
        setExpanded(!card.classList.contains('is-expanded'));
      });
    }
  });
})();
`.trim();

export function shouldRenderModeHomeDocument(document: HtmlHomeDocument): boolean {
  if (document.kind !== 'mode') {
    return false;
  }
  return true;
}

export function renderModeHomeDocument(document: HtmlHomeDocument, isBusy: boolean = false): string {
  const renderDocument: HtmlModeHomeDocumentWithBusy = {
    version: document.version,
    source: document.source,
    kind: document.kind,
    title: document.title,
    subtitle: document.subtitle,
    chips: document.chips,
    metrics: document.metrics,
    timeline: document.timeline,
    blocks: document.blocks,
    actions: document.actions,
    history: [],
    persona: document.persona,
    personaMemory: document.personaMemory,
    personaAvatarDataUri: personaAvatarDataUri(document.persona.avatarKey),
    rawSurfaceRoot: null,
    generatedAt: '',
    isBusy: isBusy || (document as HtmlModeHomeDocumentWithBusy).isBusy === true
  };
  const json = escapeScriptJson(JSON.stringify(renderDocument));
  const title = escapeHtmlText(document.title.length > 0 ? document.title : document.kind);
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${title}</title>
<style>${MODE_HOME_CSS}</style>
</head>
<body>
<div id="app"></div>
<script id="home-data" type="application/json">${json}</script>
<script>${MODE_HOME_JS}</script>
</body>
</html>`;
}

function escapeScriptJson(json: string): string {
  return json
    .split('&').join('\\u0026')
    .split('<').join('\\u003c')
    .split('>').join('\\u003e')
    .split('\u2028').join('\\u2028')
    .split('\u2029').join('\\u2029');
}

function escapeHtmlText(value: HtmlModeTextValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  return value.toString()
    .split('&').join('&amp;')
    .split('<').join('&lt;')
    .split('>').join('&gt;')
    .split('"').join('&quot;');
}
