// Remove all video IDs input from playlist edit page.

{
  let ids = prompt('').split(' ');

  function loop(ids, i) {
    if (i >= ids.length) {
      return;
    }

    let id = ids[i];
    let elts = Array.from(document.querySelectorAll('.pl-video-title-link'));
    elts = elts
      .filter(elt => {
        let eltId = elt.href.match(/v=(...........)/)[1];
        return eltId === id;
      });
    if (elts.length != 1) {
      console.log('not found');
      loop(ids, i + 1);
      return;
    }
    let button = elts[0].parentElement.parentElement
      .querySelector('.pl-video-edit-remove');
    button.click();
    setTimeout(loop, 100, ids, i + 1);
  }

  loop(ids, 0);
}
