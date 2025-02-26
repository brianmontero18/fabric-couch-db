/*
 * Chaincode para Asset Transfer con soporte para CouchDB
 */

'use strict';

const { Contract } = require('fabric-contract-api');

class AssetTransfer extends Contract {

    async InitLedger(ctx) {
        const assets = [
            {
                ID: 'asset1',
                Color: 'blue',
                Size: 5,
                Owner: 'Tom',
                AppraisedValue: 300,
                Type: 'Vehicle'
            },
            {
                ID: 'asset2',
                Color: 'red',
                Size: 10,
                Owner: 'Lisa',
                AppraisedValue: 400,
                Type: 'Property'
            },
            {
                ID: 'asset3',
                Color: 'green',
                Size: 15,
                Owner: 'John',
                AppraisedValue: 500,
                Type: 'Vehicle'
            },
            {
                ID: 'asset4',
                Color: 'yellow',
                Size: 10,
                Owner: 'David',
                AppraisedValue: 600,
                Type: 'Property'
            },
            {
                ID: 'asset5',
                Color: 'black',
                Size: 15,
                Owner: 'Maria',
                AppraisedValue: 700,
                Type: 'Vehicle'
            },
            {
                ID: 'asset6',
                Color: 'white',
                Size: 15,
                Owner: 'Alex',
                AppraisedValue: 800,
                Type: 'Property'
            },
        ];

        for (const asset of assets) {
            await ctx.stub.putState(asset.ID, Buffer.from(JSON.stringify(asset)));
            console.info(`Asset ${asset.ID} initialized`);
        }
    }

    // CreateAsset agrega un nuevo activo al world state con detalles dados
    async CreateAsset(ctx, id, color, size, owner, appraisedValue, type) {
        const asset = {
            ID: id,
            Color: color,
            Size: parseInt(size),
            Owner: owner,
            AppraisedValue: parseInt(appraisedValue),
            Type: type
        };
        await ctx.stub.putState(id, Buffer.from(JSON.stringify(asset)));
        return JSON.stringify(asset);
    }

    // ReadAsset devuelve el activo almacenado en el world state con id dado
    async ReadAsset(ctx, id) {
        const assetJSON = await ctx.stub.getState(id);
        if (!assetJSON || assetJSON.length === 0) {
            throw new Error(`Asset ${id} does not exist`);
        }
        return assetJSON.toString();
    }

    // UpdateAsset actualiza un activo existente en el world state
    async UpdateAsset(ctx, id, color, size, owner, appraisedValue, type) {
        const exists = await this.AssetExists(ctx, id);
        if (!exists) {
            throw new Error(`Asset ${id} does not exist`);
        }

        // Sobreescribir el activo original
        const updatedAsset = {
            ID: id,
            Color: color,
            Size: parseInt(size),
            Owner: owner,
            AppraisedValue: parseInt(appraisedValue),
            Type: type
        };
        await ctx.stub.putState(id, Buffer.from(JSON.stringify(updatedAsset)));
        return JSON.stringify(updatedAsset);
    }

    // DeleteAsset elimina un activo del world state
    async DeleteAsset(ctx, id) {
        const exists = await this.AssetExists(ctx, id);
        if (!exists) {
            throw new Error(`Asset ${id} does not exist`);
        }
        return ctx.stub.deleteState(id);
    }

    // AssetExists verifica si un activo con id dado existe en el world state
    async AssetExists(ctx, id) {
        const assetJSON = await ctx.stub.getState(id);
        return assetJSON && assetJSON.length > 0;
    }

    // GetAllAssets devuelve todos los activos del world state
    async GetAllAssets(ctx) {
        const allResults = [];
        const iterator = await ctx.stub.getStateByRange('', '');
        let result = await iterator.next();
        while (!result.done) {
            const strValue = Buffer.from(result.value.value.toString()).toString('utf8');
            let record;
            try {
                record = JSON.parse(strValue);
            } catch (err) {
                console.log(err);
                record = strValue;
            }
            allResults.push({ Key: result.value.key, Record: record });
            result = await iterator.next();
        }
        return JSON.stringify(allResults);
    }

    // Consulta enriquecida: Busca activos por color
    async QueryAssetsByColor(ctx, color) {
        const queryString = {
            selector: {
                Color: color
            }
        };
        return await this.GetQueryResult(ctx, JSON.stringify(queryString));
    }

    // Consulta enriquecida: Busca activos por rango de valor
    async QueryAssetsByValueRange(ctx, minValue, maxValue) {
        const queryString = {
            selector: {
                AppraisedValue: {
                    $gte: parseInt(minValue),
                    $lte: parseInt(maxValue)
                }
            }
        };
        return await this.GetQueryResult(ctx, JSON.stringify(queryString));
    }

    // Consulta enriquecida: Busca activos por tipo y rango de valor
    async QueryAssetsByTypeAndValue(ctx, type, minValue, maxValue) {
        const queryString = {
            selector: {
                Type: type,
                AppraisedValue: {
                    $gte: parseInt(minValue),
                    $lte: parseInt(maxValue)
                }
            },
            sort: [
                {AppraisedValue: "desc"}
            ]
        };
        return await this.GetQueryResult(ctx, JSON.stringify(queryString));
    }

    // Función auxiliar para ejecutar consultas CouchDB
    async GetQueryResult(ctx, queryString) {
        let resultsIterator = await ctx.stub.getQueryResult(queryString);
        let results = await this.GetAllResults(resultsIterator, false);
        return JSON.stringify(results);
    }

    // Función para iterar sobre resultados
    async GetAllResults(iterator, isHistory) {
        let allResults = [];
        let res = await iterator.next();
        while (!res.done) {
            if (res.value && res.value.value.toString()) {
                let jsonRes = {};
                if (isHistory && isHistory === true) {
                    jsonRes.TxId = res.value.txId;
                    jsonRes.Timestamp = res.value.timestamp;
                    try {
                        jsonRes.Value = JSON.parse(res.value.value.toString('utf8'));
                    } catch (err) {
                        jsonRes.Value = res.value.value.toString('utf8');
                    }
                } else {
                    jsonRes.Key = res.value.key;
                    try {
                        jsonRes.Record = JSON.parse(res.value.value.toString('utf8'));
                    } catch (err) {
                        jsonRes.Record = res.value.value.toString('utf8');
                    }
                }
                allResults.push(jsonRes);
            }
            res = await iterator.next();
        }
        await iterator.close();
        return allResults;
    }
}
