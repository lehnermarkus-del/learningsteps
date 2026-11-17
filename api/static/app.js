const $ = id => document.getElementById(id);
async function request(path, options = {}) {
  const response = await fetch(path, options);
  const data = await response.json();
  if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : 'Bitte Eingaben prüfen.');
  return data;
}
async function loadNotes() {
  const data = await request('/entries');
  $('count').textContent = `(${data.count})`;
  $('entries').replaceChildren();
  for (const entry of data.entries) {
    const node = document.createElement('article'); node.className = 'note';
    for (const [field, label] of [['work', 'Gelernt'], ['struggle', 'Schwierig'], ['intention', 'Nächstes Ziel']]) {
      const p = document.createElement('p'); const b = document.createElement('strong');
      b.textContent = label + ': '; p.append(b, document.createTextNode(entry[field])); node.append(p);
    }
    $('entries').append(node);
  }
}
$('entryForm').addEventListener('submit', async event => {
  event.preventDefault(); $('save').disabled = true;
  try {
    await request('/entries', {method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({work: $('work').value, struggle: $('struggle').value, intention: $('intention').value})});
    $('entryForm').reset(); await loadNotes(); $('status').textContent = 'Notiz gespeichert. Zusammenfassung bei Bedarf neu erstellen.';
    $('summary').textContent = 'Die Notizen wurden geändert. Bitte Zusammenfassung neu erstellen.'; $('meta').textContent = '';
  } catch (error) { $('status').textContent = error.message; }
  finally { $('save').disabled = false; }
});
$('generate').addEventListener('click', async () => {
  $('generate').disabled = true; $('status').textContent = 'Azure erstellt deinen Lernüberblick …';
  $('summary').textContent = ''; $('meta').textContent = '';
  try {
    const data = await request('/ai/summary', {method: 'POST', headers: {'X-LearningSteps-Request': 'summary'}});
    $('summary').textContent = data.summary; // Treat model output as text, never HTML.
    $('meta').textContent = `${data.entry_count} Notizen · Modell: ${data.model}`;
    $('status').textContent = 'Zusammenfassung erfolgreich erstellt.';
  } catch (error) { $('status').textContent = error.message; }
  finally { $('generate').disabled = false; }
});
loadNotes().catch(error => { $('status').textContent = error.message; });
