// Easily select all video IDs on playlist edit page to be copied.

{
  let urls =
    Array.from(document.querySelectorAll('.pl-video-title-link'))
    .map(x => x.href);
  let ids = urls
    .map(u => u.match(/v=(...........)/)[1]);
  prompt(undefined, ids.join(' '));
};
