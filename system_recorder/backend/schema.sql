CREATE TABLE IF NOT EXISTS teams (
  id VARCHAR(36) PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS players (
  id VARCHAR(36) PRIMARY KEY,
  team_id VARCHAR(36) NOT NULL,
  jersey_no INT NOT NULL,
  name VARCHAR(100) NOT NULL,
  primary_role VARCHAR(20) NOT NULL,
  height DECIMAL(5,2) NULL,
  weight DECIMAL(5,2) NULL,
  birth_date DATE NULL,
  is_active TINYINT(1) DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_players_team FOREIGN KEY (team_id) REFERENCES teams(id)
);

CREATE TABLE IF NOT EXISTS matches (
  id VARCHAR(36) PRIMARY KEY,
  team_id VARCHAR(36) NOT NULL,
  opponent_name VARCHAR(100) NOT NULL,
  match_date DATETIME DEFAULT CURRENT_TIMESTAMP,
  our_sets_won INT DEFAULT 0,
  opponent_sets_won INT DEFAULT 0,
  result VARCHAR(10) NULL,
  status VARCHAR(20) DEFAULT 'IN_PROGRESS',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_matches_team FOREIGN KEY (team_id) REFERENCES teams(id)
);

CREATE TABLE IF NOT EXISTS sets (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  match_id VARCHAR(36) NOT NULL,
  set_number INT NOT NULL,
  our_score INT NOT NULL,
  opponent_score INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_match_set (match_id, set_number),
  CONSTRAINT fk_sets_match FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS lineups (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  match_id VARCHAR(36) NOT NULL,
  set_number INT NOT NULL,
  position INT NOT NULL,
  player_id VARCHAR(36) NOT NULL,
  is_libero TINYINT(1) DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_lineups_match_set (match_id, set_number),
  CONSTRAINT fk_lineups_match FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE,
  CONSTRAINT fk_lineups_player FOREIGN KEY (player_id) REFERENCES players(id)
);

CREATE TABLE IF NOT EXISTS events (
  id VARCHAR(36) PRIMARY KEY,
  match_id VARCHAR(36) NOT NULL,
  set_number INT NOT NULL,
  rally_id VARCHAR(36) NOT NULL,
  player_id VARCHAR(36) NOT NULL,
  player_name VARCHAR(100) NOT NULL,
  jersey_no INT NOT NULL,
  player_role_at_time VARCHAR(20) NOT NULL,
  position_at_time VARCHAR(10) NOT NULL,
  category VARCHAR(30) NOT NULL,
  detail_type VARCHAR(30) NOT NULL,
  outcome VARCHAR(20) NOT NULL,
  score_team_a INT NOT NULL,
  score_team_b INT NOT NULL,
  is_our_serve TINYINT(1) NOT NULL,
  is_forced_error TINYINT(1) DEFAULT 0,
  point_reason VARCHAR(50) NULL,
  rotation_applied TINYINT(1) DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_events_match_created (match_id, created_at),
  KEY idx_events_match_set (match_id, set_number),
  KEY idx_events_player (player_id),
  CONSTRAINT fk_events_match FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE,
  CONSTRAINT fk_events_player FOREIGN KEY (player_id) REFERENCES players(id)
);

INSERT INTO teams (id, name)
VALUES ('t1', '嘉大資管')
ON DUPLICATE KEY UPDATE name = VALUES(name);
