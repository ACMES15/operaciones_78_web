const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {google} = require("googleapis");
admin.initializeApp();

const SPREADSHEET_ID = "1GxR0FckDFH_te25t3Lo27pqJoDbZbU9sTXXKDL0NLHY";
// Mapea documentId -> nombre de pestaña.
// Si no existe un mapeo, usaremos el id como nombre de pestaña.
const MODULE_SHEETS = {
  dev_xd_firmadas: "Hoja 1",
  guias_cyc: "Guias CYC",
  paqueteria_externa: "Paqueteria Externa",
  // agrega otros mapeos si quieres renombrar pestañas
};

// Encabezados utilizados en cada pestaña (orden de columnas)
const HEADERS = [
  "id",
  "nombreRecibe",
  "usuarioEntrega",
  "fechaFirma",
];

// Nombre por defecto si no hay mapeo (la función con JSDoc está más abajo)

const auth = new google.auth.GoogleAuth({
  keyFile: "service-account.json",
  scopes: ["https://www.googleapis.com/auth/spreadsheets"],
});

/**
 * Devuelve el nombre de la pestaña para un módulo.
 * @param {string} moduleId Identificador del documento/módulo.
 * @return {string} Nombre de la pestaña en la hoja de cálculo.
 */
function sheetNameForModule(moduleId) {
  return MODULE_SHEETS[moduleId] || moduleId;
}

/**
 * Asegura que exista una pestaña con el nombre solicitado en la hoja.
 * @param {object} sheets Cliente de Google Sheets.
 * @param {string} spreadsheetId Id de la hoja de cálculo.
 * @param {string} sheetName Nombre de la pestaña a asegurar.
 */
async function ensureSheetExists(sheets, spreadsheetId, sheetName) {
  const meta = await sheets.spreadsheets.get({
    spreadsheetId,
    fields: "sheets.properties",
  });
  const sheetsList = (meta.data.sheets || [])
      .map((s) => s.properties && s.properties.title);
  if (sheetsList.includes(sheetName)) return;
  await sheets.spreadsheets.batchUpdate({
    spreadsheetId,
    resource: {
      requests: [
        {addSheet: {properties: {title: sheetName}}},
      ],
    },
  });
}

/**
 * Añade filas a la pestaña correspondiente a `moduleId`.
 * @param {string} moduleId Id del módulo/documento.
 * @param {Array} values Filas a insertar (array de arrays).
 */
async function appendToSheetForModule(moduleId, values) {
  const client = await auth.getClient();
  const sheets = google.sheets({version: "v4", auth: client});
  const sheetName = sheetNameForModule(moduleId);
  await ensureSheetExists(sheets, SPREADSHEET_ID, sheetName);
  // Asegura encabezados si la hoja está vacía. Usa HEADERS por defecto.
  await writeHeadersIfEmpty(sheets, SPREADSHEET_ID, sheetName, HEADERS);
  await sheets.spreadsheets.values.append({
    spreadsheetId: SPREADSHEET_ID,
    range: sheetName + "!A1",
    valueInputOption: "USER_ENTERED",
    resource: {
      values,
    },
  });
}

/**
 * Escribe encabezados si la pestaña está vacía.
 * @param {object} sheets Cliente Google Sheets.
 * @param {string} spreadsheetId Id de la hoja.
 * @param {string} sheetName Nombre de la pestaña.
 * @param {Array<string>} headers Encabezados opcionales a escribir.
 */
async function writeHeadersIfEmpty(sheets, spreadsheetId, sheetName, headers) {
  const _sn = sheetName;
  const range = _sn + "!A1:1";
  const res = await sheets.spreadsheets.values.get({
    spreadsheetId,
    range,
  });
  const hasData = !!res.data;
  const hasVals = hasData && Array.isArray(res.data.values);
  const hasValues = hasVals && res.data.values.length;
  if (hasValues) return;
  await sheets.spreadsheets.values.update({
    spreadsheetId,
    range: _sn + "!A1",
    valueInputOption: "USER_ENTERED",
    resource: {
      values: [headers || HEADERS],
    },
  });
}

/**
 * Escribe por completo la pestaña: encabezado + todas las filas.
 * Usa para exportación completa (overwrite).
 * @param {string} moduleId Id del módulo.
 * @param {Array<Array>} rows Filas a escribir (sin encabezado).
 * @param {Array<string>} headers Encabezados opcionales (orden de columnas).
 */
async function writeFullSheetForModule(moduleId, rows, headers) {
  const client = await auth.getClient();
  const sheets = google.sheets({version: "v4", auth: client});
  const sheetName = sheetNameForModule(moduleId);
  await ensureSheetExists(sheets, SPREADSHEET_ID, sheetName);
  const useHeaders = headers || HEADERS;
  const all = [useHeaders].concat(rows || []);
  await sheets.spreadsheets.values.update({
    spreadsheetId: SPREADSHEET_ID,
    range: sheetName + "!A1",
    valueInputOption: "USER_ENTERED",
    resource: {values: all},
  });
}

/**
 * Exporta un array de documentos como un módulo (soporta full e incremental).
 * @param {string} moduleId Id lógico del módulo.
 * @param {Array<object>} docsArray Array de objetos con sus campos.
 * @param {boolean} full Si true sobrescribe la hoja; si no, incremental.
 * @param {object} db Instancia de Firestore.
 */
async function exportDocsAsModule(moduleId, docsArray, full, db) {
  const allDocs = docsArray || [];
  // Full export: detectar keys dinámicas
  if (full) {
    const keySet = new Set();
    allDocs.forEach((d) => {
      Object.keys(d || {}).forEach((k) => {
        keySet.add(k);
      });
    });
    const keys = Array.from(keySet).sort();
    if (keys.includes("id")) {
      keys.splice(keys.indexOf("id"), 1);
      keys.unshift("id");
    }
    const rows = allDocs.map((d) => {
      return keys.map((k) => {
        const v = d && d[k];
        if (v === undefined || v === null) return "";
        if (typeof v === "object") return JSON.stringify(v);
        return String(v);
      });
    });
    await writeFullSheetForModule(moduleId, rows, keys);
    await setExportControl(db, moduleId, {
      lastExportedIds: allDocs.map((d) => d.id),
      headers: keys,
    });
    return rows.length;
  }

  // Incremental: usar persisted control
  const control = await getExportControl(db, moduleId);
  const persistedIds = Array.isArray(control.lastExportedIds) ?
    control.lastExportedIds :
    [];
  const persistedHeaders = Array.isArray(control.headers) ?
    control.headers :
    null;
  const nuevos = allDocs.filter((d) => !persistedIds.includes(d.id));
  if (nuevos.length === 0) return 0;

  // Determinar todas las keys actuales
  const allKeysSet = new Set(persistedHeaders || HEADERS);
  allDocs.forEach((d) => {
    Object.keys(d || {}).forEach((k) => {
      allKeysSet.add(k);
    });
  });
  const allKeys = Array.from(allKeysSet).sort();
  if (allKeys.includes("id")) {
    allKeys.splice(allKeys.indexOf("id"), 1);
    allKeys.unshift("id");
  }

  // Si cambió el esquema, reescribimos todo
  let headersChanged = false;
  if (persistedHeaders) {
    if (persistedHeaders.length !== allKeys.length) {
      headersChanged = true;
    } else {
      headersChanged = persistedHeaders.some((h, i) => h !== allKeys[i]);
    }
  }
  if (headersChanged || !persistedHeaders) {
    const rows = allDocs.map((d) => {
      return allKeys.map((k) => {
        const v = d && d[k];
        if (v === undefined || v === null) return "";
        if (typeof v === "object") return JSON.stringify(v);
        return String(v);
      });
    });
    await writeFullSheetForModule(moduleId, rows, allKeys);
    await setExportControl(db, moduleId, {
      lastExportedIds: allDocs.map((d) => d.id),
      headers: allKeys,
    });
    return rows.length;
  }

  // Append solo nuevos con headers persistidos
  const values = nuevos.map((d) => persistedHeaders.map((k) => {
    const v = d && d[k];
    if (v === undefined || v === null) return "";
    if (typeof v === "object") return JSON.stringify(v);
    return String(v);
  }));
  await appendToSheetForModule(moduleId, values);
  await setExportControl(db, moduleId, {
    lastExportedIds: allDocs.map((d) => d.id),
    headers: persistedHeaders,
  });
  return values.length;
}

// Persistir lastExportedIds por módulo en Firestore
/**
 * Obtiene los ids ya exportados para un módulo desde Firestore.
 * @param {FirebaseFirestore.Firestore} db Instancia de Firestore.
 * @param {string} moduleId Id del módulo.
 * @return {Array<string>} Lista de ids exportados.
 */
// legacy helpers removed — use getExportControl / setExportControl instead

/**
 * Obtiene el documento de control de exportación para un módulo.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} moduleId
 * @return {object} datos guardados (puede incluir lastExportedIds y headers)
 */
async function getExportControl(db, moduleId) {
  const ref = db.collection("exports_control").doc(moduleId);
  const snap = await ref.get();
  if (!snap.exists) return {};
  return snap.data() || {};
}

/**
 * Persiste datos de control de exportación (ids y encabezados).
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} moduleId
 * @param {object} data
 */
async function setExportControl(db, moduleId, data) {
  const ref = db.collection("exports_control").doc(moduleId);
  await ref.set(data, {merge: true});
}

/**
 * Persiste la lista de ids exportados para un módulo.
 * @param {FirebaseFirestore.Firestore} db Instancia de Firestore.
 * @param {string} moduleId Id del módulo.
 * @param {Array<string>} ids Lista de ids a persistir.
 */
// legacy helpers removed — use setExportControl instead


exports.exportFirmasToSheet = functions.https.onRequest(async (req, res) => {
  const db = admin.firestore();

  // Procesar todos los documentos dentro de historial_entregas
  const collectionSnap = await db.collection("historial_entregas").get();
  // Si se llama con ?full=true hará exportación completa.
  // Sobrescribe las pestañas existentes con encabezado + datos.
  const q = req && req.query;
  let full = false;
  if (q && q.full === "true") {
    full = true;
  }
  let totalExported = 0;

  for (const doc of collectionSnap.docs) {
    const moduleId = doc.id; // p.ej. 'dev_xd_firmadas'

    // Leer subcolección firmas
    const histRef = db.collection("historial_entregas");
    const firmasRef = histRef.doc(moduleId).collection("firmas");
    const firmasSnap = await firmasRef.get();
    const firmas = firmasSnap.docs.map((d) => ({
      ...d.data(),
      id: d.id,
    }));

    // Leer items antiguos desde el documento raíz (si tiene campo items)
    const docRef = db.collection("historial_entregas").doc(moduleId);
    const docSnap = await docRef.get();
    const hasItems = docSnap.exists && Array.isArray(docSnap.data().items);
    const items = hasItems ? docSnap.data().items : [];

    // Combinar ambos, evitando duplicados por id
    const allFirmasMap = {};
    [...items, ...firmas].forEach((f) => {
      if (f && f.id) allFirmasMap[f.id] = f;
    });
    const allFirmas = Object.values(allFirmasMap);

    // Si se solicita exportación completa, sobrescribimos la pestaña
    if (full) {
      // Crear encabezados dinámicos a partir de todas las claves encontradas
      const keySet = new Set();
      allFirmas.forEach((f) => {
        Object.keys(f || {}).forEach((k) => keySet.add(k));
      });
      // Asegurar 'id' como primera columna si existe
      const keys = Array.from(keySet);
      keys.sort();
      if (keys.includes("id")) {
        keys.splice(keys.indexOf("id"), 1);
        keys.unshift("id");
      }

      // Construir filas respetando el orden de keys
      const allRows = allFirmas.map((f) => keys.map((k) => {
        const v = f && f[k];
        if (v === undefined || v === null) return "";
        if (typeof v === "object") return JSON.stringify(v);
        return String(v);
      }));

      try {
        await writeFullSheetForModule(moduleId, allRows, keys);
        // Guardar control con headers y ids
        await setExportControl(db, moduleId, {
          lastExportedIds: allFirmas.map((f) => f.id),
          headers: keys,
        });
        totalExported += allRows.length;
        console.log("Exportación completa: " + moduleId);
      } catch (err) {
        console.error("Error exportando (full)", moduleId, err);
      }
      continue;
    }

    // Obtener control persistido (ids y headers)
    const control = await getExportControl(db, moduleId);
    const persistedIds = Array.isArray(control.lastExportedIds) ?
      control.lastExportedIds :
      [];
    const persistedHeaders = Array.isArray(control.headers) ?
      control.headers :
      null;

    const nuevos = allFirmas.filter((f) => !persistedIds.includes(f.id));
    if (nuevos.length === 0) continue;

    // Revisar si hay nuevas claves que no estén en headers persistidos
    const allKeysSet = new Set(persistedHeaders || HEADERS);
    allFirmas.forEach((f) => {
      Object.keys(f || {}).forEach((k) => {
        allKeysSet.add(k);
      });
    });
    const allKeys = Array.from(allKeysSet);
    allKeys.sort();
    if (allKeys.includes("id")) {
      allKeys.splice(allKeys.indexOf("id"), 1);
      allKeys.unshift("id");
    }

    // Si el esquema cambió, rehacer la hoja completa para mantener columnas
    let headersChanged = false;
    if (persistedHeaders) {
      if (persistedHeaders.length !== allKeys.length) {
        headersChanged = true;
      } else {
        headersChanged = persistedHeaders.some((h, i) => h !== allKeys[i]);
      }
    }
    if (headersChanged || !persistedHeaders) {
      // Reescribir todo para sincronizar columnas
      const allRows = allFirmas.map((f) => allKeys.map((k) => {
        const v = f && f[k];
        if (v === undefined || v === null) return "";
        if (typeof v === "object") return JSON.stringify(v);
        return String(v);
      }));
      try {
        await writeFullSheetForModule(moduleId, allRows, allKeys);
        await setExportControl(db, moduleId, {
          lastExportedIds: allFirmas.map((f) => f.id),
          headers: allKeys,
        });
        totalExported += allRows.length;
        console.log("Sincronizada hoja para " + moduleId);
      } catch (err) {
        console.error("Error sincronizando", moduleId, err);
      }
      continue;
    }

    // Si headers persistidos están OK, solo append de nuevos usando ese orden
    const values = nuevos.map((f) => {
      return persistedHeaders.map((k) => {
        const v = f && f[k];
        if (v === undefined || v === null) return "";
        if (typeof v === "object") return JSON.stringify(v);
        return String(v);
      });
    });

    try {
      await appendToSheetForModule(moduleId, values);
      await setExportControl(db, moduleId, {
        lastExportedIds: allFirmas.map((f) => f.id),
        headers: persistedHeaders,
      });
      totalExported += nuevos.length;
      const infoPrefix = "Exportados ";
      const infoSuffix = " registros para ";
      const infoMsg = infoPrefix + nuevos.length + infoSuffix + moduleId;
      console.log(infoMsg);
    } catch (err) {
      console.error("Error exportando", moduleId, err);
    }
  }

  const msgPrefix = "Exportados ";
  const msgSuffix = " registros nuevos a Google Sheets.";
  const msg = msgPrefix + totalExported + msgSuffix;
  console.log(msg);
  res.status(200).send(msg);
});

// Procesar colecciones adicionales solicitadas
exports.exportExtraCollections = functions.https.onRequest(async (req, res) => {
  const db = admin.firestore();
  const q = req && req.query;
  const full = q && q.full === "true";
  let total = 0;

  // guias_cyc -> exportar todos los documentos de la colección
  try {
    const guiasRef = db.collection("guias_cyc");
    const snap = await guiasRef.get();
    const docs = snap.docs.map((d) => {
      return Object.assign({}, d.data(), {id: d.id});
    });
    const exported = await exportDocsAsModule(
        "guias_cyc",
        docs,
        full,
        db,
    );
    total += exported;
    console.log("Exportados guias_cyc:", exported);
  } catch (err) {
    console.error("Error exportando guias_cyc", err);
  }

  // entregas/* -> por cada documento,
  // recoger su subcolección 'paqueteria_externa'
  try {
    const entregasRef = db.collection("entregas");
    const entregasSnap = await entregasRef.get();
    const combined = [];
    for (const edoc of entregasSnap.docs) {
      try {
        const sub = await entregasRef
            .doc(edoc.id)
            .collection("paqueteria_externa")
            .get();
        sub.docs.forEach((d) => {
          const row = Object.assign({}, d.data(), {id: d.id});
          combined.push(row);
        });
      } catch (e) {
        console.warn("No hay paqueteria_externa en entregas/" + edoc.id);
      }
    }
    // además revisar entregas/*/documentos/*/paqueteria_externa
    for (const edoc of entregasSnap.docs) {
      try {
        const docsSub = await entregasRef
            .doc(edoc.id)
            .collection("documentos")
            .get();
        for (const docSub of docsSub.docs) {
          try {
            const pSub = await entregasRef
                .doc(edoc.id)
                .collection("documentos")
                .doc(docSub.id)
                .collection("paqueteria_externa")
                .get();
            pSub.docs.forEach((d) => {
              const row2 = Object.assign({}, d.data(), {id: d.id});
              combined.push(row2);
            });
          } catch (e) {
            // ignorar si no existe
          }
        }
      } catch (e) {
        // no hay subcolección 'documentos' en este doc
      }
    }
    // además revisar ruta entregas/documentos/mkp/
    // paqueteria_externa (documentos como documento raíz)
    try {
      const maybe = await db.collection("entregas")
          .doc("documentos")
          .collection("mkp")
          .collection("paqueteria_externa")
          .get();
      maybe.docs.forEach((d) => {
        const row3 = Object.assign({}, d.data(), {id: d.id});
        combined.push(row3);
      });
    } catch (e) {
      // ignorar si no existe
    }
    // deduplicar por id
    const uniqueMap = {};
    combined.forEach((it) => {
      if (it && it.id) uniqueMap[it.id] = it;
    });
    const uniqueList = Object.values(uniqueMap);
    const exported2 = await exportDocsAsModule(
        "paqueteria_externa",
        uniqueList,
        full,
        db,
    );
    total += exported2;
    console.log("Exportados paqueteria_externa (total docs):", exported2);
  } catch (err) {
    console.error("Error exportando paqueteria_externa", err);
  }

  const out = "Exportados adicionales: " + total;
  console.log(out);
  res.status(200).send(out);
});

/**
 * Función HTTP que exporta firmas nuevas a Google Sheets por módulo.
 * Se recomienda invocarla desde Cloud Scheduler cada 5 minutos.
 */
