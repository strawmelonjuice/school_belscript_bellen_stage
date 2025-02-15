import birl
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

// import lustre/ui

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", 0)

  Nil
}

// MODEL -----------------------------------------------------------------------

type Model {
  Model(
    pad: List(String),
    naam: Option(String),
    datum_gemaild: Option(String),
    antwoord_opties: List(#(String, Int)),
    huidig_script: String,
  )
}

fn init(_: Int) -> Model {
  let datum_vandaag = birl.now() |> birl.to_naive_date_string()
  Model(
    pad: [],
    antwoord_opties: [],
    naam: None,
    datum_gemaild: Some(datum_vandaag),
    huidig_script: "",
  )
}

// UPDATE ----------------------------------------------------------------------

pub opaque type Msg {
  AnswerredMsg(Int)
  NameFilledInMsg(String)
  DateFilledInMsg(String)
  GebruikerResetMsg
  FormFilledInMsg
}

fn update(model: Model, msg: Msg) -> Model {
  case msg {
    NameFilledInMsg(naam) -> Model(..model, naam: Some(naam))
    DateFilledInMsg(datum_gemaild) ->
      Model(..model, datum_gemaild: Some(datum_gemaild))
    GebruikerResetMsg ->
      Model(..model, pad: [], naam: None, datum_gemaild: None)
    AnswerredMsg(_) -> todo
    FormFilledInMsg -> {
      let te_zeggen =
        begroeting()
        <> ". U spreekt met "
        <> model.naam |> option.unwrap("[naam]")
        <> ". Ik ben student op het Koning Willem I College en heb uw bedrijf op "
        <> model.datum_gemaild |> option.unwrap("[datum gemaild]")
        <> " per email benaderd. Kunt u mij vertellen of deze email is ontvangen?"

      let antwoorden_daarop = [#("Ja", 1), #("Nee", 2), #("Weet ik niet", 3)]
      Model(
        ..model,
        pad: ["start", "0"],
        huidig_script: te_zeggen,
        antwoord_opties: antwoorden_daarop,
      )
    }
  }
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  case model.pad {
    [] -> view_start(model)
    _ ->
      html.main(
        [
          attribute.class(
            "self-center m-l-auto m-r-auto max-w-3/4 ring-offset-rose-950 text-slate-600",
          ),
        ],
        [
          html.div([attribute.class("chat-end chat")], [
            html.div([attribute.class("chat-bubble")], [
              element.text(model.huidig_script),
            ]),
          ]),
          html.div([attribute.class("chat-start chat")], [
            html.div(
              [attribute.class("join join-horizontal gap-4 chat-bubble")],
              {
                model.antwoord_opties
                |> list.map(fn(optie) {
                  html.button(
                    [
                      event.on_click(AnswerredMsg(optie.1)),
                      attribute.class("btn btn-xs"),
                    ],
                    [element.text(optie.0)],
                  )
                })
              },
            ),
          ]),
        ],
      )
  }
}

fn view_start(model: Model) {
  html.main(
    [
      attribute.class(
        "self-center m-l-auto m-r-auto max-w-3/4 ring-offset-rose-950 text-slate-600",
      ),
    ],
    [
      html.div([attribute.class("join join-vertical gap-6")], [
        html.label([attribute.class("join-item"), attribute.for("naam")], [
          element.text("Je naam?"),
          html.input([
            attribute.id("naam"),
            attribute.class("w-full input input-bordered"),
            attribute.type_("name"),
            attribute.value({ model.naam |> option.unwrap("") }),
            event.on_input(NameFilledInMsg),
          ]),
        ]),
        html.label(
          [attribute.class("join-item"), attribute.for("datum_gemaild")],
          [
            element.text("Wanneer heb je dit bedrijf gemaild?"),
            html.input([
              attribute.id("datum_gemaild"),
              attribute.class("w-full input input-bordered"),
              attribute.type_("date"),
              attribute.value({ model.datum_gemaild |> option.unwrap("") }),
              event.on_input(DateFilledInMsg),
            ]),
          ],
        ),
        html.button(
          [
            attribute.class("w-full btn btn-bordered"),
            event.on_click(GebruikerResetMsg),
          ],
          [element.text("Reset")],
        ),
        html.button(
          {
            case model.datum_gemaild, model.naam {
              Some(_), Some(_) -> [
                attribute.class(
                  "w-full btn btn-bordered btn-outline btn-success",
                ),
                event.on_click(FormFilledInMsg),
              ]
              _, _ -> [
                attribute.class("w-full btn btn-disabled btn-ghost"),
                attribute.disabled(True),
              ]
            }
          },
          [element.text("Start")],
        ),
      ]),
    ],
  )
}

// Misc.
fn begroeting() {
  let birl.TimeOfDay(uur_van_de_dag, _, _, _) = birl.get_time_of_day(birl.now())
  case uur_van_de_dag {
    0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 -> "Goedemorgen"
    12 | 13 | 14 | 15 | 16 | 17 -> "Goedemiddag"
    18 | 19 | 20 | 21 | 22 | 23 -> "Goedenavond"
    _ -> "Hallo"
  }
}
