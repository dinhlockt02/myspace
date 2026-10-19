// Source of the blocking script that applies the stored or system theme before first paint (SC-003).
// It must stay self-contained: consumers inline this text verbatim into <head> in index.html, and the
// app's theme-init-sync test fails if the two drift apart. It mirrors the resolution in ThemeProvider
// and uses the default storage key, `ui-theme`.
export const themeInitScript = `(function(){try{var t=null;try{t=localStorage.getItem('ui-theme')}catch(e){}if(t!=='light'&&t!=='dark'&&t!=='system')t='system';var d=t==='dark'||(t==='system'&&window.matchMedia('(prefers-color-scheme: dark)').matches);var r=document.documentElement;r.classList.toggle('dark',d);r.style.colorScheme=d?'dark':'light'}catch(e){}})();`
