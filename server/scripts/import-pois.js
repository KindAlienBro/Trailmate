const fs = require('fs');
const readline = require('readline');
const Database = require('better-sqlite3');
const path = require('path');

const dbPath = path.join(__dirname, '..', '..', 'india-pois.sqlite');
const geojsonlPath = path.join(__dirname, '..', '..', 'india-pois.geojsonl');

console.log(`Setting up database at ${dbPath}`);
const db = new Database(dbPath);

// Initialize DB schema
db.exec(`
  DROP TABLE IF EXISTS pois;
  DROP TABLE IF EXISTS poi_index;
  
  CREATE TABLE pois (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    osm_id TEXT,
    name TEXT,
    type TEXT,
    reason TEXT,
    lat REAL,
    lng REAL,
    notability INTEGER
  );

  CREATE VIRTUAL TABLE poi_index USING rtree(
    id,
    minX, maxX,
    minY, maxY
  );
`);

const insertPoi = db.prepare(`
  INSERT INTO pois (osm_id, name, type, reason, lat, lng, notability)
  VALUES (?, ?, ?, ?, ?, ?, ?)
`);

const insertIndex = db.prepare(`
  INSERT INTO poi_index (id, minX, maxX, minY, maxY)
  VALUES (?, ?, ?, ?, ?)
`);

function determinePoiMetadata(tags) {
  let name = tags.name || tags['name:en'] || null;
  let type = 'scenic';
  let reason = 'An interesting spot to check out.';
  let notability = 10;

  if (tags.tourism === 'viewpoint') {
    type = 'viewpoint';
    reason = 'A beautiful scenic viewpoint.';
    if (!name) name = 'Scenic Viewpoint';
    notability = 30;
  } else if (tags.waterway === 'waterfall') {
    type = 'waterfall';
    reason = 'A majestic waterfall.';
    if (!name) name = 'Hidden Waterfall';
    notability = 40;
  } else if (tags.natural === 'peak') {
    type = 'mountain_pass';
    reason = tags.ele ? `A peak at ${tags.ele}m elevation.` : 'A high mountain peak.';
    if (!name) name = 'Mountain Peak';
    notability = 20;
  } else if (tags.historic === 'fort' || tags.historic === 'castle') {
    type = 'fort';
    reason = 'A historic fort worth exploring.';
    if (!name) name = 'Historic Fort';
    notability = 40;
  } else if (tags.historic === 'palace') {
    type = 'palace';
    reason = 'A magnificent palace.';
    if (!name) name = 'Royal Palace';
    notability = 40;
  } else if (tags.historic === 'monument' || tags.historic === 'memorial') {
    type = 'monument';
    reason = 'A remarkable historical monument.';
    if (!name) name = 'Historical Monument';
    notability = 30;
  } else if (tags.historic === 'ruins' || tags.historic) {
    type = 'heritage';
    reason = 'Historical ruins to explore.';
    if (!name) name = 'Ancient Ruins';
    notability = 30;
  } else if (tags.amenity === 'restaurant') {
    type = 'restaurant';
    reason = tags.cuisine ? `Known for ${tags.cuisine.replace(/;/g, ', ')} cuisine.` : 'A highly rated local restaurant.';
    if (!name) name = 'Local Restaurant';
    notability = 15;
  } else if (tags.amenity === 'cafe') {
    type = 'cafe';
    reason = 'A great place to grab coffee and snacks.';
    if (!name) name = 'Cozy Cafe';
    notability = 15;
  } else if (tags.amenity === 'place_of_worship') {
    type = 'worship';
    reason = 'A peaceful spiritual center.';
    if (!name) name = 'Spiritual Center';
    notability = 20;
  } else if (tags.boundary === 'national_park' || tags.leisure === 'nature_reserve') {
    type = 'national_park';
    reason = 'A protected nature reserve.';
    if (!name) name = 'Nature Reserve';
    notability = 30;
  }

  // Boost notability if it's famous
  if (name) {
    const nameLower = name.toLowerCase();
    const boosts = [
      { p: ['fort', 'fortress', 'qila', 'durg'], b: 5 },
      { p: ['palace', 'mahal'], b: 5 },
      { p: ['temple', 'mandir', 'math', 'ashram'], b: 5 },
      { p: ['falls', 'waterfall'], b: 4 },
      { p: ['heritage', 'unesco'], b: 6 },
    ];
    for (const boost of boosts) {
      if (boost.p.some(p => nameLower.includes(p))) {
        notability += boost.b;
        break;
      }
    }
  }

  return { name, type, reason, notability };
}

async function runImport() {
  if (!fs.existsSync(geojsonlPath)) {
    console.error(`GeoJSONL file not found at ${geojsonlPath}`);
    process.exit(1);
  }

  console.log(`Starting import from ${geojsonlPath}`);
  
  const fileStream = fs.createReadStream(geojsonlPath);
  const rl = readline.createInterface({ input: fileStream, crlfDelay: Infinity });

  let count = 0;
  let skipped = 0;
  
  // Wrap in transaction for extreme speed
  const insertMany = db.transaction((lines) => {
    for (const line of lines) {
      if (!line.trim()) continue;
      try {
        const cleanLine = line.replace(/^\x1e\s*/, '').trim();
        if (!cleanLine) continue;
        const feature = JSON.parse(cleanLine);
        if (!feature.geometry || feature.geometry.type !== 'Point') continue;
        
        const lng = feature.geometry.coordinates[0];
        const lat = feature.geometry.coordinates[1];
        const osm_id = feature.id || (feature.properties && feature.properties['@id']) || 'unknown';
        const tags = feature.properties || {};
        
        // We only care about POIs that have a name (mostly) or are high-value
        const meta = determinePoiMetadata(tags);
        if (!meta.name) {
          skipped++;
          continue; 
        }

        const info = insertPoi.run(osm_id, meta.name, meta.type, meta.reason, lat, lng, meta.notability);
        insertIndex.run(info.lastInsertRowid, lng, lng, lat, lat);
        count++;
      } catch (e) {
        if (count === 0 && skipped === 0) console.error("Error parsing/inserting first row:", e);
      }
    }
  });

  let batch = [];
  for await (const line of rl) {
    batch.push(line);
    if (batch.length >= 10000) {
      insertMany(batch);
      batch = [];
      console.log(`Imported ${count} POIs (skipped ${skipped})...`);
    }
  }
  
  if (batch.length > 0) {
    insertMany(batch);
  }

  console.log(`Finished! Total imported: ${count}. Total unnamed/skipped: ${skipped}.`);
  
  // Optimize database size and performance
  db.exec('VACUUM;');
  db.close();
}

runImport().catch(console.error);
