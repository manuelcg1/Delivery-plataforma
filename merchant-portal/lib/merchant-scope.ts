import type {Merchant} from './types';

export function validBranchId(merchant:Merchant|undefined,branchId:string){
  return branchId&&merchant?.branches.some(branch=>branch.id===branchId)
    ? branchId
    : '';
}
