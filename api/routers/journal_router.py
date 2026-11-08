from fastapi import APIRouter, Depends, HTTPException, Request, Response
from models.entry import Entry, EntryCreate, EntryUpdate
from repositories.postgres_repository import PostgresDB
from services.entry_service import EntryService

router = APIRouter(tags=["Lerntagebuch"])


def get_entry_service(request: Request):
    db = PostgresDB()
    db.pool = request.app.state.pool
    return EntryService(db)


@router.post("/entries", status_code=201, summary="Lerneintrag erstellen")
async def create_entry(data: EntryCreate, service: EntryService = Depends(get_entry_service)):
    entry = await service.create_entry(Entry(**data.model_dump()).model_dump())
    return {"detail": "Eintrag erstellt", "entry": entry}


@router.get("/entries", summary="Alle Lerneinträge auflisten")
async def get_all_entries(service: EntryService = Depends(get_entry_service)):
    entries = await service.get_all_entries()
    return {"entries": entries, "count": len(entries)}


@router.get("/entries/{entry_id}", summary="Einzelnen Lerneintrag lesen")
async def get_entry(entry_id: str, service: EntryService = Depends(get_entry_service)):
    entry = await service.get_entry(entry_id)
    if not entry:
        raise HTTPException(404, "Eintrag nicht gefunden")
    return entry


@router.patch("/entries/{entry_id}", summary="Lerneintrag teilweise aktualisieren")
async def update_entry(entry_id: str, data: EntryUpdate, service: EntryService = Depends(get_entry_service)):
    entry = await service.update_entry(entry_id, data.model_dump(exclude_unset=True))
    if not entry:
        raise HTTPException(404, "Eintrag nicht gefunden")
    return entry


@router.delete("/entries/{entry_id}", status_code=204, summary="Einzelnen Lerneintrag löschen")
async def delete_entry(entry_id: str, service: EntryService = Depends(get_entry_service)):
    if not await service.get_entry(entry_id):
        raise HTTPException(404, "Eintrag nicht gefunden")
    await service.delete_entry(entry_id)
    return Response(status_code=204)


@router.delete("/entries", status_code=204, summary="Alle Lerneinträge löschen")
async def delete_all_entries(service: EntryService = Depends(get_entry_service)):
    await service.delete_all_entries()
    return Response(status_code=204)

