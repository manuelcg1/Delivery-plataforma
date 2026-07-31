const trackingStatuses = {
  'PICKED_UP',
  'IN_TRANSIT',
  'ARRIVED_AT_CUSTOMER',
};

const terminalDeliveryStatuses = {
  'DELIVERED',
  'FAILED',
  'CANCELLED',
  'REJECTED',
  'EXPIRED',
};

bool shouldStartTracking(String status) => status == 'PICKED_UP';
bool shouldContinueTracking(String status) => trackingStatuses.contains(status);
bool shouldStopTracking(String status) =>
    terminalDeliveryStatuses.contains(status);
