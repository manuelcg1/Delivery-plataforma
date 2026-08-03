import {describe,expect,it} from 'vitest';
import {validBranchId} from './merchant-scope';

const merchant={
  id:'merchant-1',
  name:'Don Marco',
  role:'MANAGER',
  branches:[
    {id:'branch-1',name:'Centro',status:'ACTIVE',pausedUntil:null,pauseReason:null},
    {id:'branch-2',name:'Norte',status:'ACTIVE',pausedUntil:null,pauseReason:null},
  ],
};

describe('merchant order scope',()=>{
  it('starts with all branches so new orders are not hidden',()=>{
    expect(validBranchId(merchant,'')).toBe('');
  });

  it('preserves an explicitly selected branch',()=>{
    expect(validBranchId(merchant,'branch-2')).toBe('branch-2');
  });

  it('clears a branch that belongs to another merchant',()=>{
    expect(validBranchId(merchant,'other-branch')).toBe('');
  });
});
