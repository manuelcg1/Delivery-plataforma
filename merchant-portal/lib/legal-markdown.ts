export type LegalBlock={kind:'h1'|'h2'|'li'|'note'|'p';text:string};
export const legalDocuments=[{slug:'terminos-y-condiciones',title:'Términos y Condiciones'},{slug:'politica-de-privacidad',title:'Política de Privacidad'}] as const;
/** Convierte el subconjunto de Markdown de los documentos legales en bloques simples. */
export function parseLegalMarkdown(markdown:string):LegalBlock[]{
  return markdown.split('\n').map(line=>line.trimEnd()).filter(Boolean).map(line=>
    line.startsWith('# ')?{kind:'h1',text:line.slice(2)}:
    line.startsWith('## ')?{kind:'h2',text:line.slice(3)}:
    line.startsWith('- ')?{kind:'li',text:line.slice(2)}:
    line.startsWith('> ')?{kind:'note',text:line.slice(2)}:
    {kind:'p',text:line});
}
