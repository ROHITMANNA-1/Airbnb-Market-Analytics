const DATA_PATH = '../data/processed/';
const state = { master: [], monthly: [], insights: [], filters: { neighborhood: 'all', room: 'all', search: '' } };
const $ = (selector) => document.querySelector(selector);

function parseCSV(text) {
  const rows = [];
  let row = [], cell = '', quoted = false;
  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    const next = text[index + 1];
    if (char === '"' && quoted && next === '"') { cell += '"'; index += 1; }
    else if (char === '"') quoted = !quoted;
    else if (char === ',' && !quoted) { row.push(cell); cell = ''; }
    else if ((char === '\n' || char === '\r') && !quoted) {
      if (char === '\r' && next === '\n') index += 1;
      row.push(cell); cell = '';
      if (row.some(value => value !== '')) rows.push(row);
      row = [];
    } else cell += char;
  }
  if (cell || row.length) { row.push(cell); rows.push(row); }
  const headers = rows.shift().map(header => header.trim());
  return rows.map(values => Object.fromEntries(headers.map((header, i) => [header, (values[i] || '').trim()])));
}

function number(value) { const parsed = Number(String(value).replace(/[$,%]/g, '')); return Number.isFinite(parsed) ? parsed : 0; }
function money(value, compact = false) {
  if (compact && Math.abs(value) >= 1000000) return `$${(value / 1000000).toFixed(1)}M`;
  if (compact && Math.abs(value) >= 1000) return `$${(value / 1000).toFixed(0)}K`;
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(value);
}
function percent(value) { return `${(value * 100).toFixed(1)}%`; }
function escapeHtml(value) { return String(value ?? '').replace(/[&<>"']/g, char => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#039;' }[char])); }

async function loadData() {
  const [masterResponse, monthlyResponse, insightResponse] = await Promise.all([
    fetch(`${DATA_PATH}master_analytics_table.csv`),
    fetch(`${DATA_PATH}calendar_monthly_agg.csv`),
    fetch(`${DATA_PATH}business_insights.csv`)
  ]);
  if (![masterResponse, monthlyResponse, insightResponse].every(response => response.ok)) throw new Error('Data request failed');
  state.master = parseCSV(await masterResponse.text());
  state.monthly = parseCSV(await monthlyResponse.text());
  state.insights = parseCSV(await insightResponse.text());
  populateFilters();
  renderAll();
  $('#loading').hidden = true;
  $('#dashboard').hidden = false;
}

function populateFilters() {
  const neighborhoods = [...new Set(state.master.map(row => row.neighbourhood_cleansed).filter(Boolean))].sort();
  const rooms = [...new Set(state.master.map(row => row.room_type).filter(Boolean))].sort();
  $('#neighborhood-filter').innerHTML = '<option value="all">All neighborhoods</option>' + neighborhoods.map(value => `<option value="${escapeHtml(value)}">${escapeHtml(value)}</option>`).join('');
  $('#room-filter').innerHTML = '<option value="all">All room types</option>' + rooms.map(value => `<option value="${escapeHtml(value)}">${escapeHtml(value)}</option>`).join('');
  const dates = state.monthly.map(row => row.year_month).sort();
  $('#tracked-window').textContent = `${dates[0]} — ${dates[dates.length - 1]}`;
  $('#last-updated').textContent = `${state.master.length} listings · refreshed now`;
}

function filteredRows() {
  const { neighborhood, room, search } = state.filters;
  const query = search.toLowerCase();
  return state.master.filter(row => {
    const matchNeighborhood = neighborhood === 'all' || row.neighbourhood_cleansed === neighborhood;
    const matchRoom = room === 'all' || row.room_type === room;
    const matchSearch = !query || [row.id, row.property_type, row.host_id, row.neighbourhood_cleansed].join(' ').toLowerCase().includes(query);
    return matchNeighborhood && matchRoom && matchSearch;
  });
}

function summarize(rows) {
  const revenue = rows.reduce((sum, row) => sum + number(row.revenue_estimate), 0);
  const booked = rows.reduce((sum, row) => sum + number(row.booked_nights), 0);
  const tracked = rows.reduce((sum, row) => sum + number(row.total_nights_tracked), 0);
  const actions = rows.filter(row => row.pricing_signal !== 'Well-Priced' || row.is_stale_listing === 'True').length;
  return { revenue, booked, tracked, occupancy: tracked ? booked / tracked : 0, revpar: tracked ? revenue / tracked : 0, actions };
}

function renderAll() {
  const rows = filteredRows();
  const summary = summarize(rows);
  $('#kpi-revenue').textContent = money(summary.revenue, true);
  $('#kpi-occupancy').textContent = percent(summary.occupancy);
  $('#kpi-revpar').textContent = money(summary.revpar);
  $('#kpi-listings').textContent = rows.length.toLocaleString();
  $('#kpi-listings-foot').textContent = state.filters.neighborhood === 'all' && state.filters.room === 'all' && !state.filters.search ? 'priced listings' : 'matching filters';
  $('#kpi-occupancy-foot').textContent = `${summary.tracked.toLocaleString()} tracked nights`;
  $('#kpi-actions').textContent = summary.actions.toLocaleString();
  renderSeasonality(); renderRoomMix(rows); renderNeighborhoodBars(rows); renderSignal(); renderMarketTable(rows); renderHostComparison(rows); renderPricingTable(rows); renderInsights();
}

function renderSeasonality() {
  const grouped = {};
  state.monthly.forEach(row => { grouped[row.year_month] = (grouped[row.year_month] || 0) + number(row.revenue); });
  const values = Object.entries(grouped).sort(([a], [b]) => a.localeCompare(b));
  const max = Math.max(...values.map(([, value]) => value), 1);
  $('#seasonality-chart').innerHTML = values.map(([month, value]) => `<div class="season-column"><div class="season-bar" style="height:${Math.max(3, value / max * 190)}px"><span>${money(value, true)}</span></div><div class="season-label">${month.slice(5)}</div></div>`).join('');
}

function renderRoomMix(rows) {
  const grouped = {}; rows.forEach(row => { grouped[row.room_type] = (grouped[row.room_type] || 0) + 1; });
  const entries = Object.entries(grouped).sort(([, a], [, b]) => b - a); const total = rows.length || 1;
  const colors = ['#087f73', '#e8b85b', '#ef795f', '#7a9f91']; let running = 0;
  const gradient = entries.map(([name, count], i) => { const start = running / total * 100; running += count; return `${colors[i % colors.length]} ${start}% ${running / total * 100}%`; }).join(', ');
  $('#room-mix').style.background = `conic-gradient(${gradient || '#dfe8e0 0 100%'})`;
  $('#room-mix').innerHTML = `<div class="donut-center">${rows.length}<small>listings</small></div>`;
  $('#room-legend').innerHTML = entries.map(([name, count], i) => `<div><span><i style="background:${colors[i % colors.length]}"></i>${escapeHtml(name)}</span><span>${count} · ${percent(count / total)}</span></div>`).join('');
}

function groupNeighborhoods(rows) {
  const groups = {};
  rows.forEach(row => { const name = row.neighbourhood_cleansed || 'Unspecified'; if (!groups[name]) groups[name] = { name, listings: 0, revenue: 0, booked: 0, tracked: 0, roi: 0 }; const item = groups[name]; item.listings += 1; item.revenue += number(row.revenue_estimate); item.booked += number(row.booked_nights); item.tracked += number(row.total_nights_tracked); item.roi += number(row.estimated_annual_roi_pct); });
  return Object.values(groups).map(item => ({ ...item, occupancy: item.tracked ? item.booked / item.tracked : 0, revpar: item.tracked ? item.revenue / item.tracked : 0, roi: item.listings ? item.roi / item.listings : 0 }));
}

function renderNeighborhoodBars(rows) {
  const groups = groupNeighborhoods(rows).sort((a, b) => b.revenue - a.revenue).slice(0, 6); const max = groups[0]?.revenue || 1;
  $('#neighborhood-bars').innerHTML = groups.map(item => `<div class="bar-row"><div class="bar-name" title="${escapeHtml(item.name)}">${escapeHtml(item.name)}</div><div class="bar-track"><div class="bar-fill" style="width:${item.revenue / max * 100}%"></div></div><div class="bar-value">${money(item.revenue, true)}</div></div>`).join('');
}

function renderSignal() {
  const signal = state.insights.find(row => row.InsightID === 'EXEC-02') || state.insights[0];
  if (!signal) return;
  $('#signal-theme').textContent = signal.Theme;
  $('#signal-finding').textContent = signal.Finding;
  $('#signal-recommendation').textContent = signal.Recommendation;
  $('#signal-caveat').textContent = signal.Caveat;
}

function renderMarketTable(rows) {
  const groups = groupNeighborhoods(rows).sort((a, b) => b.revenue - a.revenue);
  $('#market-table').innerHTML = groups.map(item => `<tr><td>${escapeHtml(item.name)}</td><td>${item.listings}</td><td>${money(item.revenue, true)}</td><td>${percent(item.occupancy)}</td><td>${money(item.revpar)}</td><td>${item.roi.toFixed(1)}%</td></tr>`).join('') || '<tr><td colspan="6">No rows match the current filters.</td></tr>';
}

function renderHostComparison(rows) {
  const groups = { Superhost: { booked: 0, tracked: 0 }, 'Non-superhost': { booked: 0, tracked: 0 } };
  rows.forEach(row => { const group = row.host_is_superhost === 'True' ? groups.Superhost : groups['Non-superhost']; group.booked += number(row.booked_nights); group.tracked += number(row.total_nights_tracked); });
  const values = Object.entries(groups).map(([name, item]) => [name, item.tracked ? item.booked / item.tracked : 0]); const max = Math.max(...values.map(([, value]) => value), .01);
  $('#host-comparison').innerHTML = values.map(([name, value]) => `<div class="compare-row"><div class="compare-name">${name}</div><div class="compare-track"><div class="compare-fill" style="width:${value / max * 100}%"></div></div><div class="compare-value">${percent(value)}</div></div>`).join('');
}

function renderPricingTable(rows) {
  const candidates = rows.filter(row => row.pricing_signal !== 'Well-Priced' || row.is_stale_listing === 'True').sort((a, b) => Math.abs(number(b.pricing_gap)) - Math.abs(number(a.pricing_gap))).slice(0, 18);
  $('#pricing-count').textContent = `${candidates.length} shown`;
  $('#pricing-stat').textContent = rows.filter(row => row.pricing_signal !== 'Well-Priced').length;
  $('#pricing-table').innerHTML = candidates.map(row => { const stale = row.is_stale_listing === 'True'; const signal = row.pricing_signal !== 'Well-Priced' ? row.pricing_signal : 'Stale review'; const statusClass = row.pricing_signal !== 'Well-Priced' ? 'warn' : 'stale'; return `<tr><td>${escapeHtml(row.id)}</td><td>${escapeHtml(row.neighbourhood_cleansed)}</td><td>${money(number(row.price))}</td><td>${money(number(row.adr))}</td><td>${money(number(row.pricing_gap))}</td><td><span class="status ${statusClass}">${escapeHtml(signal)}</span></td></tr>`; }).join('') || '<tr><td colspan="6">No action items match the current filters.</td></tr>';
}

function renderInsights() {
  $('#insight-grid').innerHTML = state.insights.map(row => `<article class="insight-card"><div class="insight-id"><span>${escapeHtml(row.InsightID)}</span><span>${escapeHtml(row.Theme)}</span></div><h3>${escapeHtml(row.Finding)}</h3><div class="recommendation"><b>Recommendation</b>${escapeHtml(row.Recommendation)}</div><div class="card-caveat">${escapeHtml(row.Caveat)}</div></article>`).join('');
}

function setView(view) {
  document.querySelectorAll('.nav-item').forEach(button => button.classList.toggle('active', button.dataset.view === view));
  document.querySelectorAll('[data-panel]').forEach(panel => { panel.hidden = panel.dataset.panel !== view; });
  const titles = { overview: 'Know where the market is moving.', market: 'Find the next neighborhood to watch.', pricing: 'Turn outliers into an action list.', insights: 'From signal to decision.' };
  $('#page-title').textContent = titles[view];
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

document.querySelectorAll('.nav-item').forEach(button => button.addEventListener('click', () => setView(button.dataset.view)));
document.querySelectorAll('[data-view-target]').forEach(button => button.addEventListener('click', () => setView(button.dataset.viewTarget)));
$('#neighborhood-filter').addEventListener('change', event => { state.filters.neighborhood = event.target.value; renderAll(); });
$('#room-filter').addEventListener('change', event => { state.filters.room = event.target.value; renderAll(); });
$('#listing-search').addEventListener('input', event => { state.filters.search = event.target.value; renderAll(); });
$('#clear-filters').addEventListener('click', () => { state.filters = { neighborhood: 'all', room: 'all', search: '' }; $('#neighborhood-filter').value = 'all'; $('#room-filter').value = 'all'; $('#listing-search').value = ''; renderAll(); });
$('#refresh-data').addEventListener('click', () => { $('#dashboard').hidden = true; $('#loading').hidden = false; loadData().catch(showError); });
function showError(error) { console.error(error); $('#loading').hidden = true; $('#error').hidden = false; }
loadData().catch(showError);
