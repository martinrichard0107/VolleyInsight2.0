const express = require('express');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const pool = require('./db');
require('dotenv').config();

const app = express();

app.use(cors());
app.use(express.json());

app.get('/api/health', async (_req, res) => {
  const [rows] = await pool.query('SELECT 1 AS ok');
  res.json({ ok: rows[0].ok === 1 });
});

app.get('/api/players', async (req, res) => {
  try {
    const teamId = req.query.team_id || 't1';
    const [rows] = await pool.execute(
      `
      SELECT id, team_id, jersey_no, name, primary_role, is_active, created_at
      FROM players
      WHERE team_id = ? AND is_active = 1
      ORDER BY jersey_no ASC
      `,
      [teamId]
    );
    res.json(rows);
  } catch (error) {
    res.status(500).json({ message: '讀取球員失敗', error: error.message });
  }
});

app.post('/api/matches/start', async (req, res) => {
  try {
    const { team_id, opponent_name } = req.body;
    if (!team_id || !opponent_name) {
      return res.status(400).json({ message: 'team_id 與 opponent_name 為必填' });
    }

    const matchId = uuidv4();
    await pool.execute(
      `
      INSERT INTO matches (id, team_id, opponent_name, status)
      VALUES (?, ?, ?, 'IN_PROGRESS')
      `,
      [matchId, team_id, opponent_name]
    );

    const [rows] = await pool.execute(`SELECT * FROM matches WHERE id = ?`, [matchId]);
    res.status(201).json({ match: rows[0] });
  } catch (error) {
    res.status(500).json({ message: '建立比賽失敗', error: error.message });
  }
});

app.post('/api/lineups/batch', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const { match_id, set_number, lineups } = req.body;
    if (!match_id || !set_number || !Array.isArray(lineups) || lineups.length === 0) {
      return res.status(400).json({ message: 'match_id、set_number、lineups 為必填' });
    }

    await connection.beginTransaction();
    await connection.execute(
      `DELETE FROM lineups WHERE match_id = ? AND set_number = ?`,
      [match_id, set_number]
    );

    for (const lineup of lineups) {
      await connection.execute(
        `
        INSERT INTO lineups (match_id, set_number, position, player_id, is_libero)
        VALUES (?, ?, ?, ?, ?)
        `,
        [
          match_id,
          set_number,
          lineup.position,
          lineup.player_id,
          lineup.is_libero ? 1 : 0,
        ]
      );
    }

    await connection.commit();
    res.status(201).json({ success: true, count: lineups.length });
  } catch (error) {
    await connection.rollback();
    res.status(500).json({ message: '儲存先發失敗', error: error.message });
  } finally {
    connection.release();
  }
});

app.post('/api/events', async (req, res) => {
  try {
    const {
      id,
      match_id,
      set_number,
      rally_id,
      player_id,
      player_name,
      jersey_no,
      player_role_at_time,
      position_at_time,
      category,
      detail_type,
      outcome,
      score_team_a,
      score_team_b,
      is_our_serve,
      is_forced_error,
      point_reason,
      rotation_applied,
    } = req.body;

    if (!id || !match_id || !set_number || !rally_id || !player_id || !category || !detail_type) {
      return res.status(400).json({ message: '缺少必要欄位' });
    }

    await pool.execute(
      `
      INSERT INTO events (
        id, match_id, set_number, rally_id, player_id, player_name, jersey_no,
        player_role_at_time, position_at_time, category, detail_type, outcome,
        score_team_a, score_team_b, is_our_serve, is_forced_error, point_reason, rotation_applied
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `,
      [
        id,
        match_id,
        set_number,
        rally_id,
        player_id,
        player_name,
        jersey_no,
        player_role_at_time,
        position_at_time,
        category,
        detail_type,
        outcome,
        score_team_a,
        score_team_b,
        is_our_serve ? 1 : 0,
        is_forced_error ? 1 : 0,
        point_reason || null,
        rotation_applied ? 1 : 0,
      ]
    );

    const [rows] = await pool.execute(`SELECT * FROM events WHERE id = ?`, [id]);
    res.status(201).json(rows[0]);
  } catch (error) {
    res.status(500).json({ message: '新增事件失敗', error: error.message });
  }
});

app.delete('/api/events/:id', async (req, res) => {
  try {
    const eventId = req.params.id;
    await pool.execute(`DELETE FROM events WHERE id = ?`, [eventId]);
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ message: '刪除事件失敗', error: error.message });
  }
});

app.patch('/api/matches/:id/finish', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const matchId = req.params.id;
    const { our_sets_won, opponent_sets_won, result, sets } = req.body;

    await connection.beginTransaction();

    await connection.execute(
      `
      UPDATE matches
      SET our_sets_won = ?, opponent_sets_won = ?, result = ?, status = 'FINISHED'
      WHERE id = ?
      `,
      [our_sets_won, opponent_sets_won, result, matchId]
    );

    await connection.execute(`DELETE FROM sets WHERE match_id = ?`, [matchId]);

    if (Array.isArray(sets)) {
      for (const item of sets) {
        await connection.execute(
          `
          INSERT INTO sets (match_id, set_number, our_score, opponent_score)
          VALUES (?, ?, ?, ?)
          `,
          [matchId, item.set_number, item.our_score, item.opponent_score]
        );
      }
    }

    await connection.commit();
    res.json({ success: true });
  } catch (error) {
    await connection.rollback();
    res.status(500).json({ message: '結束比賽失敗', error: error.message });
  } finally {
    connection.release();
  }
});

app.get('/api/matches/:id/events', async (req, res) => {
  try {
    const matchId = req.params.id;
    const [rows] = await pool.execute(
      `
      SELECT *
      FROM events
      WHERE match_id = ?
      ORDER BY created_at ASC
      `,
      [matchId]
    );
    res.json(rows);
  } catch (error) {
    res.status(500).json({ message: '讀取事件失敗', error: error.message });
  }
});

app.get('/api/matches/:id/dashboard', async (req, res) => {
  try {
    const matchId = req.params.id;
    const [rows] = await pool.execute(
      `
      SELECT
        e.player_id,
        MAX(e.player_name) AS player_name,
        MAX(e.jersey_no) AS jersey_no,
        COUNT(*) AS total_actions,
        SUM(CASE WHEN e.category = 'attack' AND e.detail_type = 'Kill' THEN 1 ELSE 0 END) AS kills,
        SUM(CASE WHEN e.category = 'serve' AND e.detail_type = 'Ace' THEN 1 ELSE 0 END) AS aces,
        SUM(CASE WHEN e.category = 'block' AND e.detail_type = 'Kill' THEN 1 ELSE 0 END) AS blocks,
        SUM(CASE WHEN e.detail_type IN ('Error', 'Fault', 'Out', 'BlockedDown') THEN 1 ELSE 0 END) AS errors
      FROM events e
      WHERE e.match_id = ?
      GROUP BY e.player_id
      ORDER BY jersey_no ASC
      `,
      [matchId]
    );
    res.json(rows);
  } catch (error) {
    res.status(500).json({ message: '讀取報表失敗', error: error.message });
  }
});

const port = Number(process.env.PORT || 3000);
app.listen(port, () => {
  console.log(`API running on http://127.0.0.1:${port}`);
});
