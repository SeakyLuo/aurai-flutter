/// Opt-in components: existing message documents keep their original styling.
const htmlMessageComponentGuide =
    'The host supplies an opt-in UI kit: use one root <section class="aurai-ui aurai-stack"> '
    '(12px 16px padding), aurai-ui--compact (8px 12px), or aurai-ui--flush (0). '
    'Do not nest aurai-ui roots or add a second outer card/padding. '
    'Use aurai-stack for vertical 12px gaps, aurai-row for wrapping controls, '
    'aurai-grid for responsive equal columns, aurai-title for headings, aurai-muted for secondary text. '
    'Use <label class="aurai-field">Label<input></label>, native select/textarea/range/checkbox, '
    'and <button type="button" class="aurai-button">; add aurai-button--primary for the main action, '
    'aurai-button--danger for destructive actions, or aurai-button--block for full width. '
    'Use aurai-actions around buttons and aurai-stat for a value; these add no extra card chrome. '
    'For tabs put native button[role=tab] controls in [data-aurai-tabs][role=tablist] '
    'with unique id, aria-controls and aria-selected; matching [role=tabpanel] elements need '
    'aria-labelledby and hidden on inactive panels. The host handles tab clicks, arrow/Home/End keys '
    'and resizes after user switching. Use stable input id/name for restoration. '
    'Use a native form and submit event for local validation. Local controls must not call AI '
    'unless the user deliberately requests it. No CDN or extra UI library is needed. ';

const htmlMessageComponentStyles = r'''
.aurai-ui{padding:12px 16px;min-width:0;color:var(--aurai-text)}
.aurai-ui.aurai-ui--compact{padding:8px 12px}
.aurai-ui.aurai-ui--flush{padding:0}
.aurai-ui :where(h1,h2,h3,p,fieldset){margin:0}
.aurai-ui :where(fieldset){border:0;padding:0;min-width:0}
.aurai-ui :where(legend){padding:0;margin-bottom:8px}
.aurai-ui :where(.aurai-stack){display:flex;flex-direction:column;gap:12px;min-width:0}
.aurai-ui.aurai-stack{display:flex;flex-direction:column;gap:12px}
.aurai-ui :where(.aurai-row,.aurai-actions){display:flex;flex-wrap:wrap;align-items:center;gap:8px;min-width:0}
.aurai-ui :where(.aurai-grid){display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,140px),1fr));gap:12px;min-width:0}
.aurai-ui :where(.aurai-grid,.aurai-row)>*{min-width:0;max-width:100%}
.aurai-ui :where(.aurai-title){font-size:1.125em;font-weight:600;line-height:1.4;overflow-wrap:anywhere}
.aurai-ui :where(.aurai-muted){color:var(--aurai-muted);font-size:.875em}
.aurai-ui :where(.aurai-stat){font-size:1.5em;font-weight:600;font-variant-numeric:tabular-nums;line-height:1.3}
.aurai-ui :where(.aurai-field){display:flex;flex-direction:column;gap:6px;min-width:0}
.aurai-ui :where(input:not([type=checkbox]):not([type=radio]):not([type=range]),textarea,select){
  width:100%;min-width:0;min-height:44px;padding:10px 12px;border:1px solid var(--aurai-border);
  border-radius:12px;background:var(--aurai-field);color:var(--aurai-text);font:inherit
}
.aurai-ui :where(textarea){resize:vertical}
.aurai-ui :where(input[type=checkbox],input[type=radio]){width:20px;height:20px;accent-color:var(--aurai-accent)}
.aurai-ui :where(input[type=range]){width:100%;min-height:44px;padding:0;accent-color:var(--aurai-accent)}
.aurai-ui :where(.aurai-button,[role=tab]){
  display:inline-flex;align-items:center;justify-content:center;gap:8px;
  min-height:44px;max-width:100%;padding:10px 14px;font:inherit;line-height:1.4;
  white-space:normal;overflow-wrap:anywhere;text-align:center;cursor:pointer;
  border:1px solid var(--aurai-border);border-radius:12px;
  color:var(--aurai-text);background:var(--aurai-field)
}
.aurai-ui :where(.aurai-button--primary){background:var(--aurai-accent);color:var(--aurai-on-accent);border-color:transparent}
.aurai-ui :where(.aurai-button--danger){color:var(--aurai-error);border-color:currentColor}
.aurai-ui :where(.aurai-button--block){width:100%}
.aurai-ui :where(button:disabled,input:disabled,textarea:disabled,select:disabled){opacity:.5;cursor:default}
.aurai-ui :where(button:focus-visible,input:focus-visible,textarea:focus-visible,select:focus-visible){outline:2px solid var(--aurai-accent);outline-offset:2px}
.aurai-ui :where([data-aurai-tabs]){display:flex;flex-wrap:wrap;gap:6px}
.aurai-ui :where([role=tab][aria-selected=true]){color:var(--aurai-on-accent);background:var(--aurai-accent);border-color:transparent}
.aurai-ui [hidden]{display:none!important}
.aurai-ui :where(img,svg,canvas){max-width:100%}
.aurai-ui :where(hr){width:100%;margin:0;border:0;border-top:1px solid var(--aurai-border)}
''';

/// Tab switching stays local and only asks for height after a user action.
const htmlMessageComponentScript = r'''
(()=>{
  const root=document.getElementById('aurai-content');
  const tabs=list=>Array.from(list.querySelectorAll('[role="tab"]')).filter(tab=>tab.closest('[data-aurai-tabs]')===list);
  for(const tab of root.querySelectorAll('.aurai-ui [data-aurai-tabs] [role="tab"]')){
    tab.tabIndex=tab.getAttribute('aria-selected')==='true'?0:-1;
  }
  function select(tab){
    const list=tab.closest('[data-aurai-tabs]');
    const ui=list.closest('.aurai-ui');
    const panel=ui.querySelector('#'+CSS.escape(tab.getAttribute('aria-controls')));
    if(!panel||panel.getAttribute('role')!=='tabpanel')return;
    for(const item of tabs(list)){
      const active=item===tab;
      item.setAttribute('aria-selected',String(active));
      item.tabIndex=active?0:-1;
      const target=ui.querySelector('#'+CSS.escape(item.getAttribute('aria-controls')));
      if(target)target.hidden=!active;
    }
    tab.focus({preventScroll:true});
    AuraiHTML.requestResize();
  }
  root.addEventListener('click',event=>{
    const tab=event.target.closest('.aurai-ui [data-aurai-tabs] [role="tab"]');
    if(!tab||tab.disabled||tab.getAttribute('aria-disabled')==='true')return;
    event.preventDefault();select(tab);
  });
  root.addEventListener('keydown',event=>{
    const tab=event.target.closest('.aurai-ui [data-aurai-tabs] [role="tab"]');
    if(!tab||!['ArrowLeft','ArrowRight','Home','End'].includes(event.key))return;
    const list=tab.closest('[data-aurai-tabs]');
    const items=tabs(list).filter(item=>!item.disabled&&item.getAttribute('aria-disabled')!=='true');
    if(items.length===0)return;
    const index=items.indexOf(tab),rtl=getComputedStyle(list).direction==='rtl';
    const next=event.key==='Home'?0:event.key==='End'?items.length-1:
      (index+((event.key==='ArrowRight')!==rtl?1:-1)+items.length)%items.length;
    event.preventDefault();select(items[next]);
  });
})();
''';
