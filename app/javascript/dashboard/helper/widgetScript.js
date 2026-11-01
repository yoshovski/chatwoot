// The server's script is indented for an ERB template; drop the shared indent so it pastes cleanly.
export const dedentScript = text => {
  const lines = text.replace(/^\n+|\s+$/g, '').split('\n');
  const indents = lines
    .filter(line => line.trim())
    .map(line => line.match(/^\s*/)[0].length);
  const shared = Math.min(...indents);
  return lines.map(line => line.slice(shared)).join('\n');
};

// The install snippet with the launcher settings the SDK reads from window.chatwootSettings.
export const buildInstallSnippet = (script, { showHome, ...settings }) => {
  if (!script) return '';
  const options = showHome ? settings : { ...settings, showHome };
  return dedentScript(script).replace(
    '<script>\n',
    `<script>\n  window.chatwootSettings = ${JSON.stringify(options)};\n`
  );
};
