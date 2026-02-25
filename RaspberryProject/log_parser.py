import csv
import os

class LogParser:
    """Parser para os arquivos CSV gerados pelo SavvyCAN."""

    def __init__(self, logs_dir):
        self.logs_dir = logs_dir

    def get_periodic_stats(self, filename):
        """Analisa um log para identificar a frequência real dos IDs."""
        file_path = os.path.join(self.logs_dir, filename)
        if not os.path.exists(file_path):
            return {}

        id_counts = {}
        last_ts = {}
        intervals = {}

        with open(file_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                try:
                    ts = int(row["Time Stamp"])
                    can_id = row["ID"]
                    
                    if can_id not in id_counts:
                        id_counts[can_id] = 0
                        intervals[can_id] = []
                    
                    id_counts[can_id] += 1
                    
                    if can_id in last_ts:
                        intervals[can_id].append(ts - last_ts[can_id])
                    
                    last_ts[can_id] = ts
                except:
                    continue

        stats = {}
        for can_id, times in intervals.items():
            if times:
                avg_ms = sum(times) / len(times) / 1000 # de microssegundos para ms
                stats[can_id] = {
                    "count": id_counts[can_id],
                    "avg_period_ms": avg_ms,
                    "hz_est": round(1000 / avg_ms, 1) if avg_ms > 0 else 0
                }
        
        return stats

    def parse_frames(self, filename, limit=100):
        """Lê frames brutos para análise de payload."""
        file_path = os.path.join(self.logs_dir, filename)
        frames = []
        if not os.path.exists(file_path): return frames

        with open(file_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            count = 0
            for row in reader:
                if count >= limit: break
                data = [int(row[f"D{i}"], 16) for i in range(1, 9) if row.get(f"D{i}")]
                frames.append({
                    "id": int(row["ID"], 16),
                    "dlc": int(row["LEN"]),
                    "data": data
                })
                count += 1
        return frames
