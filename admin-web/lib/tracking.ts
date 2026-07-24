export type CourierLocation = {
  id: string;
  courierId: string;
  deliveryId?: string;
  latitude: number;
  longitude: number;
  speed?: number;
  heading?: number;
  accuracy: number;
  altitude?: number;
  provider?: string;
  batteryLevel?: number;
  gpsTimestamp: string;
  receivedAt: string;
};

export type Tracking = {
  deliveryId: string;
  status: string;
  deliveryType: string;
  courierId?: string;
  courierName?: string;
  vehicleType?: string;
  location?: CourierLocation;
  eta?: { distanceRemainingKm?: number; estimatedMinutes: number; calculatedAt: string };
  addressLine?: string;
  district?: string;
  updatedAt: string;
};

export type DeliveryProof = {
  id: string;
  deliveryId: string;
  proofType: string;
  url?: string;
  comments?: string;
  createdAt: string;
};

export type ChatMessage = {
  id: string;
  deliveryId: string;
  senderId: string;
  senderType: string;
  channel: string;
  message: string;
  createdAt: string;
};
