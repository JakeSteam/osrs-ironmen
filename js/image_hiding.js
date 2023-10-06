window.addEventListener("load", function() {
  toggleImages();
}, false);

function toggleImages() {
  document.querySelectorAll('img')
    .forEach(i => i.hidden = !i.hidden);
}