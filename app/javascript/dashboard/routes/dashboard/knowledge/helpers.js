const DOWNLOAD_CLEANUP_DELAY = 1000;

export const MAX_CSV_BYTES = 5 * 1024 * 1024;
export const MAX_ORIGINAL_BYTES = 10 * 1024 * 1024;
export const MAX_TEXT_LENGTH = 100000;

export const download = (blob, filename) => {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  // WebKit starts blob downloads asynchronously; keep the URL alive until then.
  window.setTimeout(() => URL.revokeObjectURL(url), DOWNLOAD_CLEANUP_DELAY);
};

export const originalPayload = file =>
  new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = reject;
    reader.onload = () =>
      resolve({
        original_base64: reader.result.split(',')[1],
        filename: file.name,
        media_type: file.type || 'application/octet-stream',
      });
    reader.readAsDataURL(file);
  });
