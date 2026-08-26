-- ============================================================
-- ÇIFTLIK YÖNETİM SİSTEMİ - SUPABASE VERİTABANI ŞEMASI
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- FARMS (Çiftlikler)
-- ============================================================
CREATE TABLE farms (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  address TEXT,
  phone TEXT,
  email TEXT,
  logo_url TEXT,
  electricity_rate DECIMAL(10,4) DEFAULT 3.5,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- FARM MEMBERS (Çiftlik Üyeleri / Roller)
-- ============================================================
CREATE TABLE farm_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  farm_id UUID REFERENCES farms(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('admin', 'manager', 'worker', 'vet')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(farm_id, user_id)
);

-- ============================================================
-- ANIMALS (Hayvanlar)
-- ============================================================
CREATE TABLE animals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  farm_id UUID REFERENCES farms(id) ON DELETE CASCADE NOT NULL,
  tag_number TEXT NOT NULL,
  name TEXT,
  type TEXT NOT NULL,
  breed TEXT,
  birth_date DATE,
  gender TEXT CHECK (gender IN ('male', 'female')),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'sold', 'dead', 'transferred')),
  mother_id UUID REFERENCES animals(id),
  father_id UUID REFERENCES animals(id),
  photo_url TEXT,
  weight DECIMAL(10,2),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(farm_id, tag_number)
);

CREATE INDEX idx_animals_farm_id ON animals(farm_id);
CREATE INDEX idx_animals_status ON animals(status);
CREATE INDEX idx_animals_type ON animals(type);

-- ============================================================
-- ANIMAL VACCINATIONS (Aşı Kayıtları)
-- ============================================================
CREATE TABLE animal_vaccinations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  animal_id UUID REFERENCES animals(id) ON DELETE CASCADE NOT NULL,
  vaccine_name TEXT NOT NULL,
  vaccination_date DATE NOT NULL,
  next_vaccination_date DATE,
  veterinarian TEXT,
  cost DECIMAL(10,2),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_vaccinations_animal_id ON animal_vaccinations(animal_id);
CREATE INDEX idx_vaccinations_next_date ON animal_vaccinations(next_vaccination_date);

-- ============================================================
-- ANIMAL PREGNANCIES (Gebelik Kayıtları)
-- ============================================================
CREATE TABLE animal_pregnancies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  animal_id UUID REFERENCES animals(id) ON DELETE CASCADE NOT NULL,
  mating_date DATE NOT NULL,
  expected_birth_date DATE,
  actual_birth_date DATE,
  offspring_count INTEGER,
  is_active BOOLEAN DEFAULT TRUE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- MILK RECORDS (Süt Verimi)
-- ============================================================
CREATE TABLE milk_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  animal_id UUID REFERENCES animals(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL,
  morning_amount DECIMAL(10,2) DEFAULT 0,
  evening_amount DECIMAL(10,2) DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(animal_id, date)
);

CREATE INDEX idx_milk_records_animal_id ON milk_records(animal_id);
CREATE INDEX idx_milk_records_date ON milk_records(date);

-- ============================================================
-- VEHICLES (Araçlar & İş Makineleri)
-- ============================================================
CREATE TABLE vehicles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  farm_id UUID REFERENCES farms(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL,
  brand TEXT NOT NULL,
  model TEXT NOT NULL,
  year INTEGER,
  plate TEXT,
  current_km DECIMAL(12,2),
  working_hours DECIMAL(12,2),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'maintenance', 'broken', 'sold')),
  photo_url TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_vehicles_farm_id ON vehicles(farm_id);

-- ============================================================
-- FUEL RECORDS (Yakıt Kayıtları)
-- ============================================================
CREATE TABLE fuel_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL,
  liters DECIMAL(10,2) NOT NULL,
  price_per_liter DECIMAL(10,4) NOT NULL,
  total_cost DECIMAL(12,2) NOT NULL,
  current_km DECIMAL(12,2),
  receipt_photo_url TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_fuel_records_vehicle_id ON fuel_records(vehicle_id);
CREATE INDEX idx_fuel_records_date ON fuel_records(date);

-- ============================================================
-- MAINTENANCE RECORDS (Bakım Kayıtları)
-- ============================================================
CREATE TABLE maintenance_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE NOT NULL,
  maintenance_type TEXT NOT NULL,
  maintenance_date DATE NOT NULL,
  next_maintenance_date DATE,
  cost DECIMAL(12,2),
  service_provider TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_maintenance_vehicle_id ON maintenance_records(vehicle_id);
CREATE INDEX idx_maintenance_next_date ON maintenance_records(next_maintenance_date);

-- ============================================================
-- VEHICLE DOCUMENTS (Araç Evrakları)
-- ============================================================
CREATE TABLE vehicle_documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE NOT NULL,
  category TEXT NOT NULL,
  title TEXT NOT NULL,
  file_url TEXT NOT NULL,
  file_type TEXT NOT NULL,
  expiry_date DATE,
  uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_vehicle_docs_vehicle_id ON vehicle_documents(vehicle_id);
CREATE INDEX idx_vehicle_docs_expiry ON vehicle_documents(expiry_date);

-- ============================================================
-- BUILDINGS (Yapılar)
-- ============================================================
CREATE TABLE buildings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  farm_id UUID REFERENCES farms(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL,
  name TEXT NOT NULL,
  area DECIMAL(10,2),
  construction_year INTEGER,
  photo_url TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_buildings_farm_id ON buildings(farm_id);

-- ============================================================
-- DEVICES (Cihazlar)
-- ============================================================
CREATE TABLE devices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  building_id UUID REFERENCES buildings(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  brand TEXT,
  wattage DECIMAL(10,2) NOT NULL,
  daily_usage_hours DECIMAL(5,2) NOT NULL,
  working_days_per_month INTEGER NOT NULL DEFAULT 30,
  is_active BOOLEAN DEFAULT TRUE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_devices_building_id ON devices(building_id);

-- ============================================================
-- ENERGY READINGS (Enerji Sayaç Okumaları)
-- ============================================================
CREATE TABLE energy_readings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  building_id UUID REFERENCES buildings(id) ON DELETE CASCADE NOT NULL,
  reading_date DATE NOT NULL,
  reading DECIMAL(12,2) NOT NULL,
  previous_reading DECIMAL(12,2),
  consumption DECIMAL(12,2),
  cost DECIMAL(12,2),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- STOCK ITEMS (Stok Kalemleri)
-- ============================================================
CREATE TABLE stock_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  farm_id UUID REFERENCES farms(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  unit TEXT NOT NULL,
  current_quantity DECIMAL(12,2) DEFAULT 0,
  minimum_quantity DECIMAL(12,2) DEFAULT 0,
  unit_price DECIMAL(12,4),
  supplier TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_stock_items_farm_id ON stock_items(farm_id);
CREATE INDEX idx_stock_items_category ON stock_items(category);

-- ============================================================
-- STOCK MOVEMENTS (Stok Hareketleri)
-- ============================================================
CREATE TABLE stock_movements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  stock_item_id UUID REFERENCES stock_items(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('incoming', 'outgoing')),
  quantity DECIMAL(12,2) NOT NULL,
  unit_price DECIMAL(12,4),
  total_cost DECIMAL(12,2),
  reason TEXT,
  supplier TEXT,
  date DATE NOT NULL,
  notes TEXT,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_stock_movements_item_id ON stock_movements(stock_item_id);
CREATE INDEX idx_stock_movements_date ON stock_movements(date);

-- ============================================================
-- EXPENSES (Giderler)
-- ============================================================
CREATE TABLE expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  farm_id UUID REFERENCES farms(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  date DATE NOT NULL,
  entity_id UUID,
  entity_type TEXT,
  receipt_url TEXT,
  notes TEXT,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_expenses_farm_id ON expenses(farm_id);
CREATE INDEX idx_expenses_date ON expenses(date);
CREATE INDEX idx_expenses_category ON expenses(category);

-- ============================================================
-- DOCUMENTS (Genel Evraklar)
-- ============================================================
CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  farm_id UUID REFERENCES farms(id) ON DELETE CASCADE NOT NULL,
  entity_id UUID,
  entity_type TEXT,
  category TEXT NOT NULL,
  title TEXT NOT NULL,
  file_url TEXT NOT NULL,
  file_type TEXT NOT NULL,
  file_size INTEGER,
  expiry_date DATE,
  uploaded_by UUID REFERENCES auth.users(id),
  uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_documents_farm_id ON documents(farm_id);
CREATE INDEX idx_documents_entity ON documents(entity_id, entity_type);
CREATE INDEX idx_documents_expiry ON documents(expiry_date);

-- ============================================================
-- NOTIFICATIONS (Bildirimler)
-- ============================================================
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  farm_id UUID REFERENCES farms(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL,
  priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'critical')),
  entity_id UUID,
  entity_type TEXT,
  scheduled_at TIMESTAMPTZ NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  is_sent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_farm_id ON notifications(farm_id);
CREATE INDEX idx_notifications_scheduled ON notifications(scheduled_at);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);

-- ============================================================
-- TIMELINE EVENTS (Zaman Tüneli)
-- ============================================================
CREATE TABLE timeline_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  entity_id UUID NOT NULL,
  entity_type TEXT NOT NULL,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  amount DECIMAL(12,2),
  photo_url TEXT,
  event_date TIMESTAMPTZ NOT NULL,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_timeline_entity ON timeline_events(entity_id, entity_type);
CREATE INDEX idx_timeline_date ON timeline_events(event_date);

-- ============================================================
-- TRIGGERS: updated_at auto-update
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_farms_updated_at BEFORE UPDATE ON farms FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_animals_updated_at BEFORE UPDATE ON animals FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_vehicles_updated_at BEFORE UPDATE ON vehicles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_buildings_updated_at BEFORE UPDATE ON buildings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_stock_items_updated_at BEFORE UPDATE ON stock_items FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- TRIGGER: Stock quantity auto-update on movement
-- ============================================================
CREATE OR REPLACE FUNCTION update_stock_quantity()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.type = 'incoming' THEN
    UPDATE stock_items SET current_quantity = current_quantity + NEW.quantity WHERE id = NEW.stock_item_id;
  ELSIF NEW.type = 'outgoing' THEN
    UPDATE stock_items SET current_quantity = current_quantity - NEW.quantity WHERE id = NEW.stock_item_id;
  END IF;
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER stock_movement_trigger
  AFTER INSERT ON stock_movements
  FOR EACH ROW EXECUTE FUNCTION update_stock_quantity();

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE farms ENABLE ROW LEVEL SECURITY;
ALTER TABLE farm_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE animals ENABLE ROW LEVEL SECURITY;
ALTER TABLE animal_vaccinations ENABLE ROW LEVEL SECURITY;
ALTER TABLE animal_pregnancies ENABLE ROW LEVEL SECURITY;
ALTER TABLE milk_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE fuel_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE buildings ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE energy_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE timeline_events ENABLE ROW LEVEL SECURITY;

-- Farm members can access their farm data
CREATE POLICY "Farm members can view their farm"
  ON farms FOR SELECT
  USING (
    id IN (
      SELECT farm_id FROM farm_members WHERE user_id = auth.uid()
    ) OR owner_id = auth.uid()
  );

CREATE POLICY "Farm owner can update farm"
  ON farms FOR UPDATE
  USING (owner_id = auth.uid());

-- Animals policy
CREATE POLICY "Farm members can view animals"
  ON animals FOR SELECT
  USING (
    farm_id IN (
      SELECT farm_id FROM farm_members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Farm members can insert animals"
  ON animals FOR INSERT
  WITH CHECK (
    farm_id IN (
      SELECT farm_id FROM farm_members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Farm members can update animals"
  ON animals FOR UPDATE
  USING (
    farm_id IN (
      SELECT farm_id FROM farm_members WHERE user_id = auth.uid()
    )
  );

-- Vehicles policy
CREATE POLICY "Farm members can view vehicles"
  ON vehicles FOR SELECT
  USING (
    farm_id IN (
      SELECT farm_id FROM farm_members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Farm members can manage vehicles"
  ON vehicles FOR ALL
  USING (
    farm_id IN (
      SELECT farm_id FROM farm_members WHERE user_id = auth.uid()
    )
  );

-- Stock policy
CREATE POLICY "Farm members can view stock"
  ON stock_items FOR SELECT
  USING (
    farm_id IN (
      SELECT farm_id FROM farm_members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Farm members can manage stock"
  ON stock_items FOR ALL
  USING (
    farm_id IN (
      SELECT farm_id FROM farm_members WHERE user_id = auth.uid()
    )
  );

-- ============================================================
-- DEMO DATA (Örnek Veriler)
-- ============================================================
-- Note: Run after creating a user and farm

-- INSERT INTO farms (id, name, owner_id) VALUES ('demo-farm-id', 'Demo Çiftlik', auth.uid());
-- INSERT INTO farm_members (farm_id, user_id, role) VALUES ('demo-farm-id', auth.uid(), 'admin');

-- Demo animals
INSERT INTO animals (farm_id, tag_number, name, type, breed, birth_date, gender, status) VALUES
  ('demo-farm-id', 'TR-001', 'Bessie', 'Sığır', 'Holstein', '2020-03-15', 'female', 'active'),
  ('demo-farm-id', 'TR-002', 'Max', 'Sığır', 'Angus', '2019-07-22', 'male', 'active'),
  ('demo-farm-id', 'TR-003', 'Daisy', 'Sığır', 'Jersey', '2021-01-10', 'female', 'active'),
  ('demo-farm-id', 'KY-001', 'Pamuk', 'Koyun', 'Merinos', '2022-04-05', 'female', 'active'),
  ('demo-farm-id', 'KY-002', 'Karabaş', 'Koyun', 'Akkaraman', '2021-09-18', 'male', 'active');

-- Demo vehicles
INSERT INTO vehicles (farm_id, type, brand, model, year, plate, current_km, status) VALUES
  ('demo-farm-id', 'Traktör', 'John Deere', '5075E', 2018, '34 ABC 001', 12500, 'active'),
  ('demo-farm-id', 'Kamyon', 'Ford', 'Cargo 1830', 2015, '34 DEF 002', 85000, 'active'),
  ('demo-farm-id', 'Traktör', 'New Holland', 'T4.75', 2020, '34 GHI 003', 4200, 'active');

-- Demo stock items
INSERT INTO stock_items (farm_id, name, category, unit, current_quantity, minimum_quantity, unit_price) VALUES
  ('demo-farm-id', 'Karma Yem', 'Yem', 'kg', 850, 500, 12.5),
  ('demo-farm-id', 'Saman', 'Saman', 'balya', 120, 50, 45.0),
  ('demo-farm-id', 'Şap Aşısı', 'İlaç', 'doz', 15, 20, 85.0),
  ('demo-farm-id', 'Motorin', 'Yakıt', 'litre', 450, 200, 42.5),
  ('demo-farm-id', 'Yağ Filtresi', 'Yedek Parça', 'adet', 3, 5, 125.0);
