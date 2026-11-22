import{describe,expect,it}from'vitest';
import{legalDocuments,parseLegalMarkdown}from'./legal-markdown';
describe('documentos legales',()=>{
  it('interpreta títulos, viñetas, notas y párrafos',()=>{
    expect(parseLegalMarkdown('# T\n\n## S\n- a\n> n\ntexto')).toEqual([{kind:'h1',text:'T'},{kind:'h2',text:'S'},{kind:'li',text:'a'},{kind:'note',text:'n'},{kind:'p',text:'texto'}]);
  });
  it('publica términos y privacidad',()=>{expect(legalDocuments.map(item=>item.slug)).toEqual(['terminos-y-condiciones','politica-de-privacidad'])});
});
