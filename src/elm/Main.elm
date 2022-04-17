module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode exposing (Decoder, field, string)



-- MAIN


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type Model
    = Failure
    | Loading
    | Success Templates


type alias Templates =
    List TemplateRecord


type alias TemplateRecord =
    { templateId : Int
    , name : String
    , alias : Maybe String
    , active : Bool
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading, getTemplates )



-- UPDATE


type Msg
    = GotTemplates (Result Http.Error Templates)
    | ViewTemplate Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotTemplates result ->
            case result of
                Ok templates ->
                    ( Success templates, Cmd.none )

                Err _ ->
                    ( Failure, Cmd.none )

        ViewTemplate templateId ->
            ( model, Nav.load ("/editor.html?templateId=" ++ String.fromInt templateId) )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    section [ class "section" ]
        [ div [ class "container" ]
            [ h1 [ class "title" ] [ text "Templates" ]
            , viewTemplates model
            ]
        ]


viewTemplates : Model -> Html Msg
viewTemplates model =
    case model of
        Failure ->
            text "Failed to get the templates."

        Loading ->
            text "Loading templates..."

        Success templates ->
            table [ class "table is-striped is-fullwidth is-hoverable" ] (viewHeaders :: List.map viewTemplate templates)


viewHeaders : Html Msg
viewHeaders =
    tr [] [ th [] [ text "Name" ], th [] [ text "Alias" ], th [] [ text "Active" ], th [] [] ]


viewTemplate : TemplateRecord -> Html Msg
viewTemplate template =
    tr []
        [ td [] [ text template.name ]
        , td [] [ text <| Maybe.withDefault "" template.alias ]
        , td [] [ text <| tickMark template.active ]
        , td [] [ button [ class "button is-primary is-light is-pulled-right", onClick (ViewTemplate template.templateId) ] [ text "View" ] ]
        ]


tickMark : Bool -> String
tickMark b =
    if b then
        "✓"

    else
        ""



-- HTTP


getTemplates : Cmd Msg
getTemplates =
    Http.get
        { url = "/templates"
        , expect = Http.expectJson GotTemplates recordsDecoder
        }


recordsDecoder : Decoder Templates
recordsDecoder =
    field "templates" (Decode.list templateRecordDecoder)


templateRecordDecoder : Decoder TemplateRecord
templateRecordDecoder =
    Decode.map4 TemplateRecord
        (field "templateId" Decode.int)
        (field "name" Decode.string)
        (field "alias" (Decode.nullable Decode.string))
        (field "active" Decode.bool)
