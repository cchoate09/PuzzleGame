import {
  ACHIEVEMENTS,
  CAMPAIGN_INDEX,
  DISTRICTS,
  ROOM_DEFS,
  ROOM_LOOKUP,
} from "./generated/campaign.generated.js";

export { ACHIEVEMENTS, DISTRICTS, ROOM_DEFS };

export function getRoomById(roomId) {
  return ROOM_LOOKUP[roomId];
}

export function getDistrictById(districtId) {
  return DISTRICTS.find((district) => district.id === districtId) || null;
}

export function getRoomsForDistrict(districtId) {
  return ROOM_DEFS.filter((room) => room.districtId === districtId);
}

export function buildCampaignIndex() {
  return CAMPAIGN_INDEX;
}
