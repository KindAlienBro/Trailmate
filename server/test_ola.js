const axios = require('axios');
const dotenv = require('dotenv');
dotenv.config();

const OLA_BASE_URL = 'https://api.olamaps.io';
const getOlaApiKey = () => process.env.OLA_MAPS_API_KEY;

async function test() {
    try {
        const waypointsStr = '12.8,77.5|12.7,77.4';
        const url = `${OLA_BASE_URL}/routing/v1/directions?origin=12.9716,77.5946&destination=12.2958,76.6394&api_key=${getOlaApiKey()}&steps=true&alternatives=true&mode=bicycle&waypoints=${waypointsStr}`;
        const res = await axios.post(url);
        console.log("Status:", res.status);
    } catch (e) {
        console.error("Error:", e.response ? e.response.data : e.message);
    }
}
test();
