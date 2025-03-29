// document.addEventListener("DOMContentLoaded", function () {
//   const checkElement = setInterval(() => {
//     const commandDialog = document.querySelector(".quick-input-widget");
//     if (commandDialog) {
//       // Apply the blur effect immediately if the command dialog is visible
//       if (commandDialog.style.display !== "none") {
//         runMyScript();
//       }
//       // Create an DOM observer to 'listen' for changes in element's attribute.
//       const observer = new MutationObserver((mutations) => {
//         mutations.forEach((mutation) => {
//           if (
//             mutation.type === "attributes" &&
//             mutation.attributeName === "style"
//           ) {
//             if (commandDialog.style.display === "none") {
//               handleEscape();
//             } else {
//               // If the .quick-input-widget element (command palette) is in the DOM
//               // but no inline style display: none, show the backdrop blur.
//               runMyScript();
//             }
//           }
//         });
//       });

//       observer.observe(commandDialog, { attributes: true });

//       // Clear the interval once the observer is set
//       clearInterval(checkElement);
//     } else {
//       console.log("Command dialog not found yet. Retrying...");
//     }
//   }, 500); // Check every 500ms

//   // Execute when command palette was launched.
//   document.addEventListener("keydown", function (event) {
//     if ((event.metaKey || event.ctrlKey) && event.key === "p") {
//       event.preventDefault();
//       runMyScript();
//     } else if (event.key === "Escape" || event.key === "Esc") {
//       event.preventDefault();
//       handleEscape();
//     }
//   });

//   // Ensure the escape key event listener is at the document level
//   document.addEventListener(
//     "keydown",
//     function (event) {
//       if (event.key === "Escape" || event.key === "Esc") {
//         handleEscape();
//       }
//     },
//     true
//   );

//   function runMyScript() {
//     const targetDiv = document.querySelector(".monaco-workbench");

//     // Remove existing element if it already exists
//     const existingElement = document.getElementById("command-blur");
//     if (existingElement) {
//       existingElement.remove();
//     }

//     // Create and configure the new element
//     const newElement = document.createElement("div");
//     newElement.setAttribute("id", "command-blur");

//     // Append first
//     targetDiv.appendChild(newElement);

//     // Force a reflow before adding the active class
//     newElement.offsetHeight;

//     // Add active class to trigger transition
//     newElement.classList.add("active");

//     newElement.addEventListener("click", function () {
//       // Remove active class first to trigger transition
//       newElement.classList.remove("active");
//       // Wait for transition to complete before removing
//       setTimeout(() => {
//         newElement.remove();
//       }, 200); // Match this with your transition duration
//     });
//   }

//   // Remove the backdrop blur from the DOM when esc key is pressed.
//   function handleEscape() {
//     const element = document.getElementById("command-blur");
//     if (element) {
//       element.click();
//     }
//   }
// });
