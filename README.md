# Cloud Exam – Railway edition

Repozitár spĺňa zadanie skúšky *Základy klaudových technológií* pomocou **Railway**.

| Komponent | Tech | Dôvod | URL (po deployi) |
|-----------|------|-------|------------------|
| Front-end | statický HTML/JS | minimálny image, volá REST API | `https://<auto>.up.railway.app` |
| Back-end  | FastAPI | REST `/todos` | `https://<auto>.up.railway.app` |
| Databáza  | PostgreSQL 16 | perzistentný volume | interná |

## Rýchly štart
```bash
chmod +x deploy-railway.sh destroy-railway.sh
./deploy-railway.sh          # build + deploy (≈3 min)
# konzola vypíše live URL

