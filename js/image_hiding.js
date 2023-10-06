function toggleImages() {
  document.querySelectorAll('img')
    .forEach(i => i.hidden = !i.hidden);
}