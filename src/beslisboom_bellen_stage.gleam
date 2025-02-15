import birl
import gleam/dynamic/decode
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import plinth/javascript/storage

// import lustre/ui

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let store = case storage.local() {
    Ok(s) -> s
    Error(_) -> {
      io.println_error("Failed to get local storage")
      panic
    }
  }
  let app = lustre.simple(init, update, view(_, store))
  let assert Ok(_) = lustre.start(app, "#app", #(store, 0))

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
    emailadresgebruikt: Option(String),
    schoolnaam: Option(String),
    ballon: Bool,
  )
}

fn encode_model(model: Model) -> json.Json {
  json.object([
    #("pad", json.array(model.pad, json.string)),
    #("naam", case model.naam {
      None -> json.null()
      Some(value) -> json.string(value)
    }),
    #("datum_gemaild", case model.datum_gemaild {
      None -> json.null()
      Some(value) -> json.string(value)
    }),
    #(
      "antwoord_opties",
      json.array(model.antwoord_opties, fn(value) {
        json.preprocessed_array([json.string(value.0), json.int(value.1)])
      }),
    ),
    #("huidig_script", json.string(model.huidig_script)),
    #("emailadresgebruikt", case model.emailadresgebruikt {
      None -> json.null()
      Some(value) -> json.string(value)
    }),
    #("schoolnaam", case model.schoolnaam {
      None -> json.null()
      Some(value) -> json.string(value)
    }),
    #("ballon", json.bool(model.ballon)),
  ])
}

fn model_decoder() -> decode.Decoder(Model) {
  use pad <- decode.field("pad", decode.list(decode.string))
  use naam <- decode.field("naam", decode.optional(decode.string))
  use datum_gemaild <- decode.field(
    "datum_gemaild",
    decode.optional(decode.string),
  )
  use antwoord_opties <- decode.field(
    "antwoord_opties",
    decode.list({
      use a <- decode.field(0, decode.string)
      use b <- decode.field(1, decode.int)

      decode.success(#(a, b))
    }),
  )
  use huidig_script <- decode.field("huidig_script", decode.string)
  use emailadresgebruikt <- decode.field(
    "emailadresgebruikt",
    decode.optional(decode.string),
  )
  use schoolnaam <- decode.field("schoolnaam", decode.optional(decode.string))
  use ballon <- decode.field("ballon", decode.bool)
  decode.success(Model(
    pad:,
    naam:,
    datum_gemaild:,
    antwoord_opties:,
    huidig_script:,
    emailadresgebruikt:,
    schoolnaam:,
    ballon:,
  ))
}

const clean_model = Model(
  pad: [],
  antwoord_opties: [],
  naam: None,
  datum_gemaild: None,
  huidig_script: "",
  emailadresgebruikt: None,
  schoolnaam: Some("het Koning Willem I College"),
  ballon: True,
)

// INIT ------------------------------------------------------------------------
fn init(vars: #(storage.Storage, Int)) -> Model {
  case vars.1 {
    1 -> {
      // Debugging mode
      Model(
        pad: ["start", "0"],
        naam: Some("Bert Pieters"),
        datum_gemaild: Some("2003-02-10"),
        antwoord_opties: [#("Ja", 1), #("Nee", 2), #("Weet ik niet", 3)],
        huidig_script: "Goedemiddag. U spreekt met Bert Pieters. Ik ben student op het Koning Willem I College en heb uw bedrijf op 2003-02-10 per email benaderd. Kunt u mij vertellen of deze email is ontvangen?",
        emailadresgebruikt: Some("Jouwemail@gmail.com"),
        schoolnaam: Some("het Koning Willem I College"),
        ballon: True,
      )
    }
    _ -> {
      let saved = storage.get_item(vars.0, "last_model")
      case saved {
        Ok(saved) -> {
          let a = json.parse(saved, model_decoder())
          case a {
            Ok(a) -> a
            Error(_) -> clean_model
          }
        }
        Error(_) -> clean_model
      }
    }
  }
}

// UPDATE ----------------------------------------------------------------------

pub opaque type Msg {
  AnswerredMsg(Int)
  NameFilledInMsg(String)
  DateFilledInMsg(String)
  SchoolFilledInMsg(String)
  EmailAdressFilledInMsg(String)
  GebruikerResetMsg
}

fn update(model: Model, msg: Msg) -> Model {
  case msg {
    NameFilledInMsg(naam) -> Model(..model, naam: Some(naam))
    DateFilledInMsg(datum_gemaild) ->
      Model(..model, datum_gemaild: Some(datum_gemaild))
    GebruikerResetMsg -> clean_model
    AnswerredMsg(answer) ->
      case model.pad, answer {
        [], _ -> {
          let te_zeggen =
            begroeting()
            <> ". U spreekt met "
            <> model.naam |> option.unwrap("[naam]")
            <> ". Ik ben student op "
            <> model.schoolnaam |> option.unwrap("[schoolnaam]")
            <> " en heb uw bedrijf op "
            <> model.datum_gemaild |> option.unwrap("[datum gemaild]")
            <> " per email benaderd. Kunt u mij vertellen of deze email is ontvangen?"

          let antwoorden_daarop = [
            #("Ja", 1),
            #("Nee", 2),
            #("Weet ik niet", 3),
          ]
          Model(
            ..model,
            pad: ["start", "0"],
            huidig_script: te_zeggen,
            antwoord_opties: antwoorden_daarop,
          )
        }
        _, _ -> {
          Model(
            ..model,
            huidig_script: "Er is nog geen vervolg voor deze keuze, uh-oh.",
            antwoord_opties: [],
            ballon: False,
          )
        }
      }
    EmailAdressFilledInMsg(mail) ->
      Model(..model, emailadresgebruikt: Some(mail))
    SchoolFilledInMsg(schoolname) ->
      Model(..model, schoolnaam: Some(schoolname))
  }
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model, store: storage.Storage) -> Element(Msg) {
  encode_model(model)
  |> json.to_string()
  |> storage.set_item(store, "last_model", _)
  |> result.unwrap(Nil)
  case model.pad {
    [] -> view_start(model)
    _ ->
      html.main(
        [
          attribute.class(
            "self-center m-l-auto m-r-auto max-w-3/4 ring-offset-rose-950 text-base",
          ),
        ],
        [
          html.span(
            // floating button to reset the form
            [
              attribute.class(
                "absolute top-2 right-2 m-2 btn btn-xs btn-warning",
              ),
              event.on_click(GebruikerResetMsg),
            ],
            [html.i([attribute.class("fa-solid fa-rotate-left w-30")], [])],
          ),
          case model.ballon {
            True -> {
              html.div([attribute.class("chat-end chat")], [
                html.div([attribute.class("chat-bubble")], [
                  element.text(model.huidig_script),
                ]),
              ])
            }
            False ->
              html.div([attribute.class("")], [
                element.text(model.huidig_script),
              ])
          },
          html.div([attribute.class("chat-start chat")], [
            html.div(
              case model.antwoord_opties {
                [] -> []
                _ -> [attribute.class("join join-horizontal gap-1 chat-bubble")]
              },
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
        "self-center m-l-auto m-r-auto max-w-3/4 ring-offset-rose-950 text-base",
      ),
    ],
    [
      html.div([attribute.class("join join-vertical gap-2")], [
        html.label([attribute.class("join-item"), attribute.for("naam")], [
          element.text("Je naam?"),
          html.input([
            attribute.placeholder("Bert Pieters"),
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
              attribute.placeholder(datum_vandaag()),
              attribute.value({ model.datum_gemaild |> option.unwrap("") }),
              event.on_input(DateFilledInMsg),
            ]),
          ],
        ),
        html.label(
          [attribute.class("join-item"), attribute.for("mail_gebruikt")],
          [
            element.text("Met welk adres heb je gemaild?"),
            html.input([
              attribute.id("mail_gebruikt"),
              attribute.class("w-full input input-bordered"),
              attribute.type_("mail"),
              attribute.placeholder("jij@jouwschool-edu.nl"),
              attribute.value({ model.emailadresgebruikt |> option.unwrap("") }),
              event.on_input(EmailAdressFilledInMsg),
            ]),
          ],
        ),
        html.label(
          [attribute.class("join-item"), attribute.for("mail_gebruikt")],
          [
            element.text("Op welke school zit je?"),
            html.input([
              attribute.id("mail_gebruikt"),
              attribute.class("w-full input input-bordered"),
              attribute.type_("text"),
              attribute.value({
                model.schoolnaam |> option.unwrap("het Koning Willem I College")
              }),
              event.on_input(EmailAdressFilledInMsg),
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
            case
              model.datum_gemaild,
              model.naam,
              model.emailadresgebruikt,
              model.schoolnaam
            {
              Some(_), Some(_), Some(_), Some(_) -> [
                // Formulier is ingevuld, laat gebruiker starten
                attribute.class(
                  "w-full btn btn-bordered btn-outline btn-success",
                ),
                event.on_click(AnswerredMsg(0)),
                attribute.type_("submit"),
              ]
              _, _, _, _ -> [
                // Formulier is niet ingevuld, laat gebruiker niet starten
                attribute.class("w-full btn btn-disabled btn-ghost"),
                attribute.disabled(True),
                attribute.type_("submit"),
              ]
            }
          },
          [element.text("Start")],
        ),
      ]),
    ],
  )
}

// Time-based personalisation functions -------------------------------------------------------
fn begroeting() {
  let birl.TimeOfDay(uur_van_de_dag, _, _, _) = birl.get_time_of_day(birl.now())
  case uur_van_de_dag {
    0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 -> "Goedemorgen"
    12 | 13 | 14 | 15 | 16 | 17 -> "Goedemiddag"
    18 | 19 | 20 | 21 | 22 | 23 -> "Goedenavond"
    _ -> "Hallo"
  }
}

fn afscheid() {
  case birl.now() |> birl.weekday() {
    birl.Mon | birl.Tue | birl.Wed | birl.Thu -> "Fijne dag"
    birl.Fri -> "Fijn weekend"
    _ -> "Fijne rest van uw weekend"
  }
}

fn datum_vandaag() {
  let wrong = birl.now() |> birl.to_naive_date_string()
  // this creates a "YYYY-MM-DD" string
  // we need to split it into parts and reformat it to "DD-MM-YYYY"
  let splitted = wrong |> string.split("-")
  let year = splitted |> list.first() |> result.unwrap("2025")
  let splitted = splitted |> list.rest() |> result.unwrap(["02", "15"])
  let month = splitted |> list.first() |> result.unwrap("02")
  let splitted = splitted |> list.rest() |> result.unwrap(["15"])
  let day = splitted |> list.last() |> result.unwrap("15")
  day <> "-" <> month <> "-" <> year
}
