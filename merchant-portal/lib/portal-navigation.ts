const permissions:Record<string,string>={
  orders:'MERCHANT_ORDERS_VIEW',catalog:'CATALOG_PRODUCTS_VIEW',inventory:'CATALOG_INVENTORY_VIEW',
  branches:'MERCHANT_BRANCH_OPERATE',schedules:'CATALOG_HOURS_VIEW',payments:'PAYMENT_VIEW',
  reports:'MERCHANT_REPORTS_VIEW',team:'IDENTITY_USERS_VIEW',notifications:'NOTIFICATION_VIEW',settings:'CATALOG_MERCHANTS_UPDATE',
};
export function canOpenPortalPage(path:string,granted:readonly string[]):boolean {
  const page=path.split('/')[1];
  if(page==='schedules'&&granted.includes('MERCHANT_BRANCH_OPERATE'))return true;
  const permission=permissions[page];
  return !!permission&&granted.includes(permission);
}
