local Database = {}

-- Retrieves all mechanic shops from the database
function Database.GetAllShops()
    local result = MySQL.query.await('SELECT * FROM mechanic_shops')
    if result then
        for _, shop in ipairs(result) do
            shop.zones = json.decode(shop.zones)
            shop.lifts = json.decode(shop.lifts)
            shop.vehicleSpawns = json.decode(shop.vehicleSpawns)
        end
    end
    return result or {}
end

-- Updates a mechanic shop with new data
function Database.UpdateShop(shopId, data)
    local query = 'UPDATE mechanic_shops SET zones = ?, lifts = ?, vehicleSpawns = ? WHERE id = ?'
    local params = {json.encode(data.zones), json.encode(data.lifts), json.encode(data.vehicleSpawns), shopId}
    return MySQL.update.await(query, params) > 0
end

-- Creates a new mechanic shop
function Database.CreateShop(data)
    local query = 'INSERT INTO mechanic_shops (name, price, zones, lifts, vehicleSpawns) VALUES (?, ?, ?, ?, ?)'
    local params = {data.name, data.price, json.encode(data.zones), json.encode(data.lifts), json.encode(data.vehicleSpawns)}
    return MySQL.insert.await(query, params)
end

-- Updates the vehicle data, including colors and other properties
function Database.UpdateVehicleProperties(plate, properties)
    local query = 'UPDATE player_vehicles SET props = ? WHERE plate = ?'
    local params = {json.encode(properties), plate}
    return MySQL.update.await(query, params) > 0
end

return Database
