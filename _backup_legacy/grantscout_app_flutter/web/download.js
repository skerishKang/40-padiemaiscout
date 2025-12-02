function triggerDownload(url, filename) {
  console.log("Triggering download for:", url, "with filename:", filename);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = filename; // 명시적으로 파일명 지정
  document.body.appendChild(anchor);
  anchor.click();
  document.body.removeChild(anchor);
  console.log("Download triggered.");
} 