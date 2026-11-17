import asyncio

from fastapi import APIRouter, Depends, Header, HTTPException, Response
from routers.journal_router import get_entry_service
from services.entry_service import EntryService
from services.summary_service import summarize

router = APIRouter(tags=["KI-Zusammenfassung"])
_running = asyncio.Lock()


@router.post("/ai/summary", summary="Alle gespeicherten Notizen mit Azure zusammenfassen")
async def create_summary(response: Response, service: EntryService = Depends(get_entry_service),
                         x_learningsteps_request: str = Header(default="")):
    response.headers["Cache-Control"] = "no-store"
    # Custom header prevents cross-origin HTML forms from spending model quota.
    # This is CSRF protection, NOT user authentication (single-user lab only).
    if x_learningsteps_request != "summary":
        raise HTTPException(403, "Zusammenfassung nur über die Anwendung anfordern.")
    if _running.locked():
        raise HTTPException(429, "Eine Zusammenfassung wird bereits erstellt.")
    async with _running:
        return await summarize(await service.get_all_entries())
