// Runs inside the official PITC bill page shown in the app, after the user
// has opened their own bill. Returns the page's tables (rows of cell text)
// and visible text as JSON. It only reads; it never submits or clicks.
(function () {
  function clean(t) { return (t || '').replace(/\s+/g, ' ').trim().slice(0, 200); }
  var tables = Array.prototype.slice.call(document.querySelectorAll('table'), 0, 200).map(function (t) {
    return Array.prototype.slice.call(t.rows, 0, 200).map(function (r) {
      return Array.prototype.slice.call(r.cells, 0, 40).map(function (c) { return clean(c.innerText); });
    });
  });
  var text = document.body ? document.body.innerText : '';
  return JSON.stringify({ text: text.slice(0, 20000), tables: tables });
})();
